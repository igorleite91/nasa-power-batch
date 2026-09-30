# Funções para baixar séries diárias da NASA POWER para uma lista de pontos.
#
# Este arquivo só define funções; nada é executado ao carregá-lo com source().
# O ponto de entrada de linha de comando é baixar_nasa_power.R, na raiz.
#
# Documentação da API: https://power.larc.nasa.gov/docs/services/api/temporal/daily/

POWER_URL <- "https://power.larc.nasa.gov/api/temporal/daily/point"

# Variáveis baixadas por padrão (mesmo conjunto da versão original do script).
PARAMETROS_PADRAO <- c(
  "TOA_SW_DWN",        # irradiância no topo da atmosfera (MJ/m²/dia)
  "ALLSKY_SFC_SW_DWN", # irradiância na superfície, céu real (MJ/m²/dia)
  "T2M",               # temperatura média a 2 m (°C)
  "T2M_MIN",           # temperatura mínima a 2 m (°C)
  "T2M_MAX",           # temperatura máxima a 2 m (°C)
  "RH2M",              # umidade relativa a 2 m (%)
  "WS2M",              # velocidade do vento a 2 m (m/s)
  "PRECTOTCORR"        # precipitação corrigida (mm/dia)
)

COLUNAS_OBRIGATORIAS <- c(
  "id_da_estacao", "latitude", "longitude", "data_inicio", "data_fim"
)

# O registro diário da POWER começa em 1981-01-01.
DATA_MINIMA_POWER <- as.Date("1981-01-01")

# A API aceita no máximo 20 parâmetros por requisição de ponto.
MAX_PARAMETROS <- 20L


# Leitura e validação da tabela de estações --------------------------------

#' Lê a tabela de estações (.csv ou .xlsx) e valida seu conteúdo.
#'
#' @param caminho Caminho para um arquivo .csv (UTF-8, separador vírgula) ou
#'   .xlsx/.xls (primeira aba).
#' @return data.frame com as colunas obrigatórias, datas como `Date`.
ler_estacoes <- function(caminho) {
  if (!file.exists(caminho)) {
    stop("Arquivo de estações não encontrado: ", caminho, call. = FALSE)
  }

  extensao <- tolower(tools::file_ext(caminho))
  estacoes <- switch(
    extensao,
    csv = utils::read.csv(
      caminho,
      stringsAsFactors = FALSE,
      fileEncoding = "UTF-8",
      check.names = FALSE
    ),
    xlsx = ,
    xls = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Para ler .xlsx instale o pacote readxl: ",
             "install.packages(\"readxl\")", call. = FALSE)
      }
      as.data.frame(readxl::read_excel(caminho))
    },
    stop("Formato não suportado: .", extensao, " (use .csv ou .xlsx)",
         call. = FALSE)
  )

  validar_estacoes(estacoes)
}

#' Valida e normaliza uma tabela de estações já carregada.
#'
#' Interrompe com uma mensagem que aponta a linha problemática, em vez de
#' deixar a API devolver um erro genérico no meio do lote.
validar_estacoes <- function(estacoes) {
  faltando <- setdiff(COLUNAS_OBRIGATORIAS, names(estacoes))
  if (length(faltando) > 0) {
    stop("Colunas obrigatórias ausentes: ", paste(faltando, collapse = ", "),
         call. = FALSE)
  }
  if (nrow(estacoes) == 0) {
    stop("A tabela de estações está vazia.", call. = FALSE)
  }

  estacoes$id_da_estacao <- as.character(estacoes$id_da_estacao)
  estacoes$latitude <- as.numeric(estacoes$latitude)
  estacoes$longitude <- as.numeric(estacoes$longitude)
  estacoes$data_inicio <- como_data(estacoes$data_inicio)
  estacoes$data_fim <- como_data(estacoes$data_fim)

  erros <- character()
  linha <- seq_len(nrow(estacoes)) + 1L # +1 por causa do cabeçalho

  checar <- function(condicao, mensagem) {
    ruins <- which(is.na(condicao) | !condicao)
    if (length(ruins) > 0) {
      erros <<- c(erros, sprintf("linha %d (%s): %s", linha[ruins],
                                 estacoes$id_da_estacao[ruins], mensagem))
    }
  }

  checar(!is.na(estacoes$id_da_estacao) & nzchar(estacoes$id_da_estacao),
         "id_da_estacao vazio")
  checar(estacoes$latitude >= -90 & estacoes$latitude <= 90,
         "latitude fora de [-90, 90] ou não numérica")
  checar(estacoes$longitude >= -180 & estacoes$longitude <= 180,
         "longitude fora de [-180, 180] ou não numérica")
  checar(!is.na(estacoes$data_inicio), "data_inicio inválida")
  checar(!is.na(estacoes$data_fim), "data_fim inválida")
  checar(estacoes$data_inicio >= DATA_MINIMA_POWER,
         "data_inicio anterior a 1981-01-01 (início do registro POWER)")
  checar(estacoes$data_inicio <= estacoes$data_fim,
         "data_inicio posterior a data_fim")

  duplicados <- duplicated(estacoes$id_da_estacao)
  checar(!duplicados, "id_da_estacao repetido")

  if (length(erros) > 0) {
    stop("Problemas na tabela de estações:\n  ",
         paste(erros, collapse = "\n  "), call. = FALSE)
  }

  estacoes
}

#' Converte datas vindas de CSV (texto ISO) ou Excel (POSIXct/Date) em `Date`.
como_data <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  x <- trimws(as.character(x))
  formatos <- c("%Y-%m-%d", "%d/%m/%Y", "%Y%m%d")
  resultado <- as.Date(rep(NA_character_, length(x)))
  for (formato in formatos) {
    pendentes <- is.na(resultado) & !is.na(x)
    resultado[pendentes] <- as.Date(x[pendentes], format = formato)
  }
  resultado
}


# Requisição à API --------------------------------------------------------

#' Monta a requisição HTTP para um ponto, com retentativas e limite de taxa.
montar_requisicao <- function(latitude, longitude, data_inicio, data_fim,
                              parametros = PARAMETROS_PADRAO,
                              comunidade = "AG") {
  httr2::request(POWER_URL) |>
    httr2::req_url_query(
      parameters = paste(parametros, collapse = ","),
      community = comunidade,
      latitude = format(latitude, nsmall = 4, scientific = FALSE),
      longitude = format(longitude, nsmall = 4, scientific = FALSE),
      start = format(data_inicio, "%Y%m%d"),
      end = format(data_fim, "%Y%m%d"),
      format = "JSON",
      `time-standard` = "LST"
    ) |>
    httr2::req_user_agent(
      "nasa-power-batch (https://github.com/igorleite91/nasa-power-batch)"
    ) |>
    httr2::req_timeout(120) |>
    # Até 1 requisição/segundo: evita sobrecarregar o serviço público.
    httr2::req_throttle(rate = 1) |>
    # Repete em falhas transitórias (429 e 5xx) com espera exponencial.
    httr2::req_retry(max_tries = 4) |>
    # Erros 4xx são tratados por nós, para exibir a mensagem da API.
    httr2::req_error(is_error = function(resp) FALSE)
}

#' Converte o JSON da API em data.frame no formato longo por data.
#'
#' Valores iguais ao `fill_value` informado pela API (normalmente -999,
#' usado para dias ainda não processados ou sem dado) viram `NA`.
#'
#' @param conteudo Lista resultante de `jsonlite::fromJSON(..., simplifyVector = FALSE)`
#'   ou `httr2::resp_body_json()`.
#' @param id Identificador da estação.
#' @param latitude,longitude Coordenadas informadas pelo usuário.
interpretar_resposta <- function(conteudo, id, latitude, longitude) {
  valores <- conteudo$properties$parameter
  if (is.null(valores) || length(valores) == 0) {
    stop("Resposta da API sem o bloco properties$parameter.", call. = FALSE)
  }

  fill_value <- conteudo$header$fill_value
  if (is.null(fill_value)) fill_value <- -999

  datas_texto <- names(valores[[1]])
  df <- data.frame(
    id_da_estacao = rep(id, length(datas_texto)),
    Date = as.Date(datas_texto, format = "%Y%m%d"),
    stringsAsFactors = FALSE
  )

  for (nome in names(valores)) {
    serie <- valores[[nome]]
    # Garante o alinhamento pelas datas, não pela ordem dos elementos.
    v <- vapply(datas_texto, function(d) {
      x <- serie[[d]]
      if (is.null(x)) NA_real_ else as.numeric(x)
    }, numeric(1), USE.NAMES = FALSE)
    v[!is.na(v) & abs(v - fill_value) < 1e-9] <- NA_real_
    df[[nome]] <- v
  }

  coordenadas <- conteudo$geometry$coordinates
  df$latitude <- latitude
  df$longitude <- longitude
  df$elevacao_m <- if (length(coordenadas) >= 3) {
    as.numeric(coordenadas[[3]])
  } else {
    NA_real_
  }
  df
}

#' Baixa a série de uma única estação.
baixar_estacao <- function(id, latitude, longitude, data_inicio, data_fim,
                           parametros = PARAMETROS_PADRAO,
                           comunidade = "AG") {
  resposta <- montar_requisicao(latitude, longitude, data_inicio, data_fim,
                                parametros, comunidade) |>
    httr2::req_perform()

  status <- httr2::resp_status(resposta)
  conteudo <- tryCatch(
    httr2::resp_body_json(resposta, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (status != 200) {
    detalhe <- if (!is.null(conteudo$messages)) {
      paste(unlist(conteudo$messages), collapse = " ")
    } else {
      httr2::resp_status_desc(resposta)
    }
    stop(sprintf("HTTP %d: %s", status, detalhe), call. = FALSE)
  }

  interpretar_resposta(conteudo, id, latitude, longitude)
}


# Processamento em lote ----------------------------------------------------

#' Baixa todas as estações, com cache por estação e relatório de falhas.
#'
#' @param estacoes data.frame validado por `validar_estacoes()`.
#' @param dir_cache Pasta onde cada estação é salva ao terminar. Se o
#'   processo for interrompido, rodar de novo pula as que já foram baixadas.
#'   Use `NULL` para desativar.
#' @return Lista com `dados` (data.frame único) e `falhas` (data.frame com
#'   id e mensagem de erro de cada estação que não pôde ser baixada).
baixar_nasa_power <- function(estacoes,
                              parametros = PARAMETROS_PADRAO,
                              comunidade = "AG",
                              dir_cache = "cache") {
  if (length(parametros) > MAX_PARAMETROS) {
    stop("A API aceita no máximo ", MAX_PARAMETROS,
         " parâmetros por requisição.", call. = FALSE)
  }
  if (!is.null(dir_cache)) dir.create(dir_cache, showWarnings = FALSE,
                                      recursive = TRUE)

  n <- nrow(estacoes)
  resultados <- vector("list", n)
  falhas <- data.frame(id_da_estacao = character(), erro = character(),
                       stringsAsFactors = FALSE)

  for (i in seq_len(n)) {
    e <- estacoes[i, ]
    arquivo_cache <- if (!is.null(dir_cache)) {
      file.path(dir_cache, nome_cache(e, parametros, comunidade))
    }

    if (!is.null(arquivo_cache) && file.exists(arquivo_cache)) {
      message(sprintf("[%d/%d] %s: em cache, pulando", i, n, e$id_da_estacao))
      cache <- utils::read.csv(arquivo_cache, stringsAsFactors = FALSE)
      cache$Date <- as.Date(cache$Date)
      cache$id_da_estacao <- as.character(cache$id_da_estacao)
      resultados[[i]] <- cache
      next
    }

    message(sprintf("[%d/%d] %s: baixando %s a %s", i, n, e$id_da_estacao,
                    e$data_inicio, e$data_fim))

    df <- tryCatch(
      baixar_estacao(e$id_da_estacao, e$latitude, e$longitude,
                     e$data_inicio, e$data_fim, parametros, comunidade),
      error = function(err) {
        message("  falhou: ", conditionMessage(err))
        falhas[nrow(falhas) + 1, ] <<- list(e$id_da_estacao,
                                            conditionMessage(err))
        NULL
      }
    )

    if (!is.null(df)) {
      if (!is.null(arquivo_cache)) {
        utils::write.csv(df, arquivo_cache, row.names = FALSE,
                         fileEncoding = "UTF-8")
      }
      resultados[[i]] <- df
    }
  }

  resultados <- Filter(Negate(is.null), resultados)
  dados <- if (length(resultados) > 0) {
    do.call(rbind, resultados)
  } else {
    data.frame()
  }
  rownames(dados) <- NULL

  list(dados = dados, falhas = falhas)
}

#' Nome do arquivo de cache de uma estação.
#'
#' Inclui uma assinatura curta da requisição (coordenadas, período,
#' parâmetros e comunidade): se qualquer um deles mudar, o cache antigo é
#' ignorado em vez de devolver dados de outra consulta.
nome_cache <- function(estacao, parametros, comunidade) {
  chave <- paste(estacao$latitude, estacao$longitude, estacao$data_inicio,
                 estacao$data_fim, paste(parametros, collapse = ","),
                 comunidade, sep = "|")
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines(chave, tmp, useBytes = TRUE)
  assinatura <- substr(unname(tools::md5sum(tmp)), 1, 8)
  paste0(nome_seguro(estacao$id_da_estacao), "_", assinatura, ".csv")
}

#' Transforma um id em nome de arquivo seguro (sem barras, espaços etc.).
nome_seguro <- function(x) {
  gsub("[^A-Za-z0-9._-]", "_", as.character(x))
}
