<div align="center">

# nasa-power-batch

### Batch download of **NASA POWER daily weather data** for a list of stations or points

*Your stations go in; a daily series ready to regress against your in-situ measurements comes out.*

[![verificacao](https://github.com/igorleite91/nasa-power-batch/actions/workflows/verificacao.yml/badge.svg)](https://github.com/igorleite91/nasa-power-batch/actions/workflows/verificacao.yml)
[![R](https://img.shields.io/badge/R-%E2%89%A5%204.1-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![httr2](https://img.shields.io/badge/httr2-retry%20%2B%20throttle-276DC3)](https://httr2.r-lib.org/)
[![NASA POWER](https://img.shields.io/badge/NASA%20POWER-Daily%20API%20v2-0B3D91?logo=nasa&logoColor=white)](https://power.larc.nasa.gov/)
[![License: MIT](https://img.shields.io/badge/License-MIT-2f6b42.svg)](LICENSE)

[Português](README.md) · **[English](README.en.md)**

</div>

---

<div align="center">
<img src="docs/img/exemplo.png" width="100%" alt="Daily temperature and monthly rainfall for 2024 at Aracaju, Brasília and Três Lagoas, downloaded with this repository">
<sub><i>Real output: the three stations in <code>exemplos/estacoes.csv</code>, year 2024, downloaded by the script and plotted with <code>docs/gerar_figura.R</code>.</i></sub>
</div>

---

> The code, messages and column names are in Portuguese, since the main audience is
> Brazilian agronomy and forestry. Everything below maps them to English.

## Why

[NASA POWER](https://power.larc.nasa.gov/) provides free, global daily series of temperature,
humidity, wind, radiation and rainfall since 1981 — a great stand-in when there is no weather
station near your study area. Its web viewer, however, works **one point at a time**. This
repository reads a table of points and downloads all of them in one go.

## What it does

1. Reads the station table (`.csv` or `.xlsx`) and **validates it before downloading**
   (columns, coordinates, dates, start ≥ 1981, duplicate IDs), pointing to the offending row.
2. Queries the [POWER Daily API](https://power.larc.nasa.gov/docs/services/api/temporal/daily/)
   for each point, **throttled to 1 request/s**, with **automatic retries** on transient
   errors (HTTP 429/5xx).
3. **Turns the `-999` fill value into `NA`**, so unprocessed recent days don't silently wreck
   averages and sums.
4. Keeps a **per-station cache**, so an interrupted batch resumes where it stopped. The cache
   is invalidated when period, coordinates or variables change.
5. A failing station **does not stop the batch**; it is logged to `*_falhas.csv` with the
   API's own error message.
6. Writes **one UTF-8 CSV**, one row per station × day.

## Quick start

```bash
git clone https://github.com/igorleite91/nasa-power-batch.git
cd nasa-power-batch
Rscript -e 'install.packages(c("httr2", "jsonlite", "readxl"), repos = "https://cloud.r-project.org")'

Rscript baixar_nasa_power.R                                   # bundled example, 2024
Rscript baixar_nasa_power.R my_stations.xlsx out/weather.csv  # your data
Rscript baixar_nasa_power.R stations.csv out.csv --parametros=T2M,PRECTOTCORR
Rscript baixar_nasa_power.R --ajuda                           # all options
```

## Input table

| Column | Meaning | Example |
|---|---|---|
| `id_da_estacao` | unique station ID | `Aracaju_SE` |
| `latitude` | decimal degrees, south negative | `-10.95` |
| `longitude` | decimal degrees, west negative | `-37.05` |
| `data_inicio` | start date (`yyyy-mm-dd`, `dd/mm/yyyy` or Excel date), ≥ 1981-01-01 | `2024-01-01` |
| `data_fim` | end date | `2024-12-31` |

## Output

`id_da_estacao`, `Date`, one column per requested POWER parameter, `latitude`, `longitude`
and `elevacao_m` (grid-cell elevation reported by the API). The default parameters —
`TOA_SW_DWN`, `ALLSKY_SFC_SW_DWN`, `T2M`, `T2M_MIN`, `T2M_MAX`, `RH2M`, `WS2M`,
`PRECTOTCORR` — are exactly the inputs needed for **FAO-56 Penman-Monteith reference
evapotranspiration**. Any other variable from the
[parameter dictionary](https://power.larc.nasa.gov/parameters/) can be requested (max. 20).

## Pairing with in-situ stations (regression)

The motivating use case: download POWER **at your own weather stations' coordinates** and fit
a regression between measured and gridded values — to correct POWER's bias, fill station gaps
or extend the record back before the station existed. `id_da_estacao` + `Date` are the join
keys; the Portuguese README has a tested example with a time-based hold-out. Validate on a
held-out period (not random days), and pair rainfall on accumulated totals or with quantile
mapping rather than daily linear regression.

## Caveats

- **Gridded reanalysis/satellite data, not station measurements**: MERRA-2 meteorology
  (~0.5° × 0.625°) and CERES/FLASHFlux radiation (~1°). A point represents its grid cell.
- **Rainfall is the least certain variable**; local convective extremes are smoothed.
- **The most recent days come back as `NA`** until POWER processes them.
- Days follow **local solar time (LST)**.

## Tests

```bash
Rscript tests/testthat.R
```

Tests run **offline** against real API responses stored in `tests/testthat/fixtures/`, on
Linux and Windows in CI, together with `lintr`.

## Citing

See [`CITATION.cff`](CITATION.cff) (GitHub's **"Cite this repository"** button). Please also
acknowledge the data source as requested by the
[POWER referencing guide](https://power.larc.nasa.gov/docs/referencing/), including service
name, version and access date.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Issues and pull requests
in English are perfectly fine.

## License

[MIT](LICENSE).

---

<div align="center">
<sub>Developed by <a href="https://github.com/igorleite91">Igor Leite</a> · If it helped, leave a ⭐</sub>
</div>
