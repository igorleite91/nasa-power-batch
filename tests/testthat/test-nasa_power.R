# Os testes não acessam a internet: as respostas da API são fixtures reais
# gravadas em tests/testthat/fixtures/ e servidas por um mock do httr2.

ler_fixture <- function(nome) {
  jsonlite::fromJSON(testthat::test_path("fixtures", nome), simplifyVector = FALSE)
}

estacao_exemplo <- function(...) {
  base <- data.frame(
    id_da_estacao = "Aracaju_SE",
    latitude = -10.95,
    longitude = -37.05,
    data_inicio = "2024-01-01",
    data_fim = "2024-01-03",
    stringsAsFactors = FALSE
  )
  modificacoes <- list(...)
  for (n in names(modificacoes)) base[[n]] <- modificacoes[[n]]
  base
}

# Leitura e validação -----------------------------------------------------

test_that("como_data aceita ISO, formato brasileiro, compacto e POSIXct", {
  expect_equal(como_data("2024-03-05"), as.Date("2024-03-05"))
  expect_equal(como_data("05/03/2024"), as.Date("2024-03-05"))
  expect_equal(como_data("20240305"), as.Date("2024-03-05"))
  expect_equal(como_data(as.POSIXct("2024-03-05", tz = "UTC")),
               as.Date("2024-03-05"))
  expect_true(is.na(como_data("ontem")))
})

test_that("validar_estacoes aceita uma tabela correta", {
  e <- validar_estacoes(estacao_exemplo())
  expect_s3_class(e$data_inicio, "Date")
  expect_type(e$latitude, "double")
})

test_that("validar_estacoes aponta colunas ausentes", {
  e <- estacao_exemplo()
  e$latitude <- NULL
  expect_error(validar_estacoes(e), "latitude")
})

test_that("validar_estacoes aponta a linha com problema", {
  expect_error(validar_estacoes(estacao_exemplo(latitude = 95)),
               "linha 2 \\(Aracaju_SE\\).*latitude")
  expect_error(validar_estacoes(estacao_exemplo(data_inicio = "1970-01-01")),
               "1981")
  expect_error(validar_estacoes(estacao_exemplo(data_fim = "2023-01-01")),
               "posterior")
  duas <- rbind(estacao_exemplo(), estacao_exemplo())
  expect_error(validar_estacoes(duas), "repetido")
})

test_that("ler_estacoes lê o CSV de exemplo do repositório", {
  e <- ler_estacoes(testthat::test_path("..", "..", "exemplos", "estacoes.csv"))
  expect_equal(nrow(e), 3)
  expect_true(all(COLUNAS_OBRIGATORIAS %in% names(e)))
})

test_that("ler_estacoes lê .xlsx quando readxl está instalado", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")
  arquivo <- withr::local_tempfile(fileext = ".xlsx")
  e <- estacao_exemplo()
  e$data_inicio <- as.Date(e$data_inicio)
  e$data_fim <- as.Date(e$data_fim)
  writexl::write_xlsx(e, arquivo)
  lido <- ler_estacoes(arquivo)
  expect_equal(lido$data_inicio, as.Date("2024-01-01"))
})

# Interpretação da resposta ------------------------------------------------

test_that("interpretar_resposta monta uma linha por dia e uma coluna por variável", {
  df <- interpretar_resposta(ler_fixture("resposta_ok.json"),
                             "Aracaju_SE", -10.95, -37.05)
  expect_equal(nrow(df), 3)
  expect_equal(df$Date, as.Date(c("2024-01-01", "2024-01-02", "2024-01-03")))
  expect_true(all(PARAMETROS_PADRAO %in% names(df)))
  expect_equal(df$T2M, c(27.88, 28.04, 28.45))
  expect_equal(df$PRECTOTCORR, c(0.07, 0.08, 1.79))
  expect_equal(unique(df$elevacao_m), 12.7)
  expect_equal(names(df)[1:2], c("id_da_estacao", "Date"))
})

test_that("valores -999 (fill_value) viram NA em vez de entrar nas médias", {
  df <- interpretar_resposta(ler_fixture("resposta_fill_value.json"),
                             "Aracaju_SE", -10.95, -37.05)
  expect_equal(nrow(df), 10)
  expect_equal(sum(is.na(df$T2M)), 3)
  expect_false(any(df$T2M == -999, na.rm = TRUE))
  expect_equal(df$PRECTOTCORR[4], 0) # zero de chuva é dado, não ausência
})

# Requisição ------------------------------------------------------------------

test_that("montar_requisicao gera a URL esperada", {
  req <- montar_requisicao(-10.95, -37.05, as.Date("2024-01-01"),
                           as.Date("2024-01-03"), c("T2M", "PRECTOTCORR"))
  url <- utils::URLdecode(req$url)
  expect_match(url, "^https://power.larc.nasa.gov/api/temporal/daily/point\\?")
  expect_match(url, "parameters=T2M,PRECTOTCORR")
  expect_match(url, "start=20240101")
  expect_match(url, "end=20240103")
  expect_match(url, "community=AG")
  expect_match(url, "latitude=-10.95")
})

# Lote completo, com a API simulada --------------------------------------------

simular_api <- function() {
  ok <- readBin(testthat::test_path("fixtures", "resposta_ok.json"), "raw", 1e6)
  erro <- readBin(testthat::test_path("fixtures", "resposta_erro_422.json"), "raw", 1e6)
  function(req) {
    if (grepl("NAO_EXISTE", req$url) || grepl("latitude=0\\.", req$url)) {
      httr2::response(422, headers = "Content-Type: application/json",
                      body = erro)
    } else {
      httr2::response(200, headers = "Content-Type: application/json",
                      body = ok)
    }
  }
}

test_that("baixar_nasa_power junta estações e registra falhas sem parar o lote", {
  httr2::local_mocked_responses(simular_api())
  estacoes <- validar_estacoes(rbind(
    estacao_exemplo(),
    estacao_exemplo(id_da_estacao = "Ponto_ruim", latitude = 0.5)
  ))

  r <- suppressMessages(baixar_nasa_power(estacoes, dir_cache = NULL))
  expect_equal(nrow(r$dados), 3)
  expect_equal(unique(r$dados$id_da_estacao), "Aracaju_SE")
  expect_equal(r$falhas$id_da_estacao, "Ponto_ruim")
  expect_match(r$falhas$erro, "HTTP 422.*NAO_EXISTE")
})

test_that("o cache evita baixar de novo e é invalidado se o período mudar", {
  cache <- withr::local_tempdir()
  chamadas <- 0
  api <- simular_api()
  httr2::local_mocked_responses(function(req) {
    chamadas <<- chamadas + 1
    api(req)
  })

  e <- validar_estacoes(estacao_exemplo())
  primeira <- suppressMessages(baixar_nasa_power(e, dir_cache = cache))
  segunda <- suppressMessages(baixar_nasa_power(e, dir_cache = cache))
  expect_equal(chamadas, 1)
  expect_equal(segunda$dados, primeira$dados)

  e2 <- validar_estacoes(estacao_exemplo(data_fim = "2024-02-01"))
  suppressMessages(baixar_nasa_power(e2, dir_cache = cache))
  expect_equal(chamadas, 2)
})

test_that("baixar_nasa_power recusa mais de 20 parâmetros", {
  e <- validar_estacoes(estacao_exemplo())
  expect_error(baixar_nasa_power(e, parametros = paste0("P", 1:21)), "20")
})

test_that("nome_seguro remove caracteres problemáticos para nomes de arquivo", {
  expect_equal(nome_seguro("Est. 01/São Paulo"), "Est._01_S_o_Paulo")
})
