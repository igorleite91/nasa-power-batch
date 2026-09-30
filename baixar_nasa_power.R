#!/usr/bin/env Rscript
# Baixa dados diários da NASA POWER para uma lista de estações/pontos.
#
# Uso:
#   Rscript baixar_nasa_power.R [estacoes] [saida] [opções]
#
# Exemplos:
#   Rscript baixar_nasa_power.R
#   Rscript baixar_nasa_power.R minhas_estacoes.xlsx resultado.csv
#   Rscript baixar_nasa_power.R estacoes.csv saida.csv --parametros=T2M,PRECTOTCORR
#
# Opções:
#   --parametros=A,B,C  variáveis POWER (padrão: as 8 de PARAMETROS_PADRAO)
#   --comunidade=AG     AG (agro), RE (energia) ou SB (edificações)
#   --cache=pasta       pasta de cache por estação (padrão: cache)
#   --sem-cache         não usa nem grava cache
#   --ajuda             mostra esta mensagem
#
# Também pode ser executado no RStudio: ajuste os valores padrão abaixo e
# clique em "Source".

# Valores padrão -----------------------------------------------------------
ARQUIVO_ESTACOES <- "exemplos/estacoes.csv"
ARQUIVO_SAIDA <- "saida/dados_nasa_power.csv"

# Localiza a pasta deste script, para que source() funcione de qualquer lugar.
pasta_script <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) > 0) return(dirname(normalizePath(sub("^--file=", "", arg))))
  # Quando carregado via source(), usa o frame mais interno que tem 'ofile'.
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) return(dirname(normalizePath(frame$ofile)))
  }
  getwd()
}
source(file.path(pasta_script(), "R", "nasa_power.R"), encoding = "UTF-8")

# Argumentos ---------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (any(args %in% c("--ajuda", "-h", "--help"))) {
  linhas <- readLines(file.path(pasta_script(), "baixar_nasa_power.R"),
                      encoding = "UTF-8")
  cat(sub("^# ?", "", linhas[2:17]), sep = "\n")
  quit(status = 0)
}

opcao <- function(nome, padrao) {
  hit <- grep(paste0("^--", nome, "="), args, value = TRUE)
  if (length(hit) == 0) padrao else sub(paste0("^--", nome, "="), "", hit[1])
}

posicionais <- args[!startsWith(args, "--")]
arquivo_estacoes <- if (length(posicionais) >= 1) posicionais[1] else ARQUIVO_ESTACOES
arquivo_saida <- if (length(posicionais) >= 2) posicionais[2] else ARQUIVO_SAIDA

parametros <- strsplit(opcao("parametros", paste(PARAMETROS_PADRAO, collapse = ",")),
                       ",", fixed = TRUE)[[1]]
parametros <- toupper(trimws(parametros))
comunidade <- toupper(opcao("comunidade", "AG"))
dir_cache <- if ("--sem-cache" %in% args) NULL else opcao("cache", "cache")

# Execução ------------------------------------------------------------------
estacoes <- ler_estacoes(arquivo_estacoes)
message(sprintf("%d estação(ões) lida(s) de %s", nrow(estacoes), arquivo_estacoes))

resultado <- baixar_nasa_power(estacoes, parametros, comunidade, dir_cache)

dir.create(dirname(arquivo_saida), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(resultado$dados, arquivo_saida, row.names = FALSE,
                 na = "", fileEncoding = "UTF-8")
message(sprintf("%d linhas gravadas em %s", nrow(resultado$dados), arquivo_saida))

if (nrow(resultado$falhas) > 0) {
  arquivo_falhas <- sub("(\\.csv)?$", "_falhas.csv", arquivo_saida)
  utils::write.csv(resultado$falhas, arquivo_falhas, row.names = FALSE,
                   fileEncoding = "UTF-8")
  message(sprintf("%d estação(ões) falharam; detalhes em %s",
                  nrow(resultado$falhas), arquivo_falhas))
  if (!interactive()) quit(status = 1)
}
