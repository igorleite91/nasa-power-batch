# Executa a suíte de testes.
#   Rscript tests/testthat.R      (a partir da raiz do repositório)
library(testthat)

raiz <- if (file.exists("R/nasa_power.R")) "." else ".."
source(file.path(raiz, "R", "nasa_power.R"), encoding = "UTF-8")

test_dir(file.path(raiz, "tests", "testthat"), reporter = "progress",
         stop_on_failure = TRUE, load_package = "none")
