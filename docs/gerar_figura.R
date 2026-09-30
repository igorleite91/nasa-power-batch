# Gera docs/img/exemplo.png a partir da saída de baixar_nasa_power.R.
#
# Uso (na raiz do repositório):
#   Rscript baixar_nasa_power.R
#   Rscript docs/gerar_figura.R saida/dados_nasa_power.csv
#
# Requer ggplot2 e as colunas T2M, T2M_MIN, T2M_MAX e PRECTOTCORR na saída.

suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
entrada <- if (length(args) >= 1) args[1] else "saida/dados_nasa_power.csv"
saida <- if (length(args) >= 2) args[2] else "docs/img/exemplo.png"

d <- read.csv(entrada, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
d$Date <- as.Date(d$Date)
d$estacao <- factor(gsub("_", " ", d$id_da_estacao),
                    levels = unique(gsub("_", " ", d$id_da_estacao)))
d$mes <- as.Date(format(d$Date, "%Y-%m-01"))

paineis <- c("Temperatura do ar a 2 m (°C)", "Precipitação mensal (mm)")
temp <- transform(d, painel = factor(paineis[1], paineis))
chuva <- aggregate(PRECTOTCORR ~ estacao + mes, d, sum, na.action = na.omit)
chuva$painel <- factor(paineis[2], paineis)

meses <- c("jan", "fev", "mar", "abr", "mai", "jun",
           "jul", "ago", "set", "out", "nov", "dez")

grafico <- ggplot() +
  geom_ribbon(data = temp, aes(Date, ymin = T2M_MIN, ymax = T2M_MAX),
              fill = "#e8a33d", alpha = 0.35) +
  geom_line(data = temp, aes(Date, T2M), colour = "#b5541c", linewidth = 0.35) +
  geom_col(data = chuva, aes(mes + 14, PRECTOTCORR), fill = "#2f6b9a",
           width = 24) +
  facet_grid(painel ~ estacao, scales = "free_y", switch = "y") +
  scale_x_date(labels = function(x) meses[as.integer(format(x, "%m"))],
               date_breaks = "2 months", expand = c(0.01, 0)) +
  labs(
    x = NULL, y = NULL,
    title = sprintf("Séries diárias NASA POWER — %s",
                    paste(unique(format(range(d$Date), "%Y")), collapse = "–")),
    subtitle = paste("Faixa: mínima–máxima diária · linha: média diária ·",
                     "barras: soma mensal de PRECTOTCORR"),
    caption = paste("Gerado a partir de", basename(entrada))
  ) +
  theme_minimal(base_size = 11) +
  theme(
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 90, face = "bold"),
    strip.text.x = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(colour = "grey35"),
    plot.caption = element_text(colour = "grey50"),
    plot.background = element_rect(fill = "white", colour = NA)
  )

ggsave(saida, grafico, width = 10, height = 5.6, dpi = 150)
message("Figura salva em ", saida)
