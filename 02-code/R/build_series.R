# =============================================================================
# build_series.R
# Construeix les sèries temporals de l'informe a partir dels fitxers Dades_20XX.
#
#   - demanda   : sol·licitants en 1a preferència (juny)        [1.1.6, 2020-2025]
#   - oferta    : places de preinscripció                        [1.1.5, 2020-2025]
#   - pressio   : ràtio sol·licitants / plaça                    [derivat]
#   - matricula : matrícula de nou accés (participants)          [7.5,   2016-2025]
#   - notes     : resum anual de les notes de tall               [5.3,   2016-2025]
#   - pau       : resultats agregats de les PAU (presentats,     [CSV,   2011-2026]
#                 mitjana d'expedient, de PAU i d'accés)
#
# Defineix build_all() i tidy_series(); no executa res en ser carregat.
# Per generar la sortida: 02-code/run_analysis.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
})

# Ruta del fitxer actual, tant si s'ha carregat amb source() com amb Rscript.
this_file <- function() {
  for (f in rev(sys.frames())) if (!is.null(f$ofile)) return(normalizePath(f$ofile, mustWork = FALSE))
  args <- commandArgs(FALSE)
  hit <- grep("^--file=", args, value = TRUE)
  if (length(hit)) return(normalizePath(sub("^--file=", "", hit[1]), mustWork = FALSE))
  NA_character_
}

# Carrega els lectors des de la mateixa carpeta si encara no hi són.
if (!exists("read_places")) {
  .d <- tryCatch(dirname(this_file()), error = function(e) NA_character_)
  .cand <- c(
    if (!is.na(.d)) file.path(.d, "read_sheets.R"),
    "02-code/R/read_sheets.R", "R/read_sheets.R"
  )
  .hit <- Find(file.exists, .cand)
  if (is.null(.hit)) stop("No s'ha trobat read_sheets.R")
  source(.hit)
}

# Cerca ascendent de la carpeta 01-dades a partir del directori de treball.
find_data_dir <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    cand <- file.path(d, "01-dades")
    if (dir.exists(cand)) return(cand)
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  stop("No s'ha trobat la carpeta 01-dades a partir de: ", start)
}

# Terra de l'escala de nota de tall (5,0). Els valors < 5 d'alguns anys antics
# són anòmals respecte a l'escala 5-14 i es tracten com a terra (vegeu informe).
CUTOFF_FLOOR <- 5.0

# Llindars per mirar la distribució de notes de tall per damunt de la mediana.
# Tots són > CUTOFF_FLOOR, així que el terra de 5,0 no els afecta.
CUTOFF_THRESHOLDS <- c(6, 7, 8, 9, 10, 11, 12)

# Dades provisionals de 2026 del "Dossier Preinscripció 2026" (Departament de
# Recerca i Universitats, 10/07/2026), única font disponible fins que es publiqui
# Dades_2026.xlsx. El dossier és un resum de premsa i, per al 2025, els seus
# totals no coincideixen exactament amb els de les pestanyes:
#   - places: dossier 41.866 vs 1.1.5 41.801 (+0,2%). NO és una diferència real:
#     comparant per universitat, 5 de 8 quadren a la plaça exacta; el desajust és
#     només com es reparteixen els graus compartits i els centres mixtos.
#   - sol·licitants: dossier 62.238 vs 1.1.6 63.038 (-1,3%). És una diferència de
#     moment de tall, no d'abast: la pestanya 1.1.6 és el recompte "al tancament"
#     (definitiu) i el dossier n'és una instantània anterior. El recompte final
#     surt ~1,3% per damunt del dossier.
# Per això el punt de 2026 NO es copia tal qual: s'obté encadenant la variació
# interanual del dossier (-4,2%) sobre el nivell "al tancament" de 2025 de la
# sèrie pròpia. Així el 2026 estima el que dirà el Dades_2026.xlsx definitiu
# (~60.420) i s'evita un salt artificial. Es marca com a `provisional`.
# Vegeu el README per al detall.
DOSSIER_2026 <- list(
  sol_2025 = 62238, sol_2026 = 59653,   # estudiants preinscrits (dossier, làmines 2 i 4)
  plc_2025 = 41866, plc_2026 = 41872    # oferta de places (dossier, làmina 3)
)

# Afegeix el punt provisional de 2026 a una sèrie anual, encadenant la variació
# del dossier sobre el valor de `base_year`. `col` és la columna de nivell.
chain_2026 <- function(df, col, r_2026, r_2025, base_year = 2025L) {
  base <- df[[col]][df$year == base_year]
  nou  <- tibble(year = 2026L, !!col := round(base * r_2026 / r_2025), provisional = TRUE)
  bind_rows(mutate(df, provisional = FALSE), nou)
}

build_all <- function(data_dir = find_data_dir()) {
  files  <- sort(list.files(data_dir, pattern = "^Dades_20\\d\\d\\.xlsx$", full.names = TRUE))
  latest <- files[which.max(year_from_file(files))]

  # oferta i demanda (un punt per fitxer), 2020-2025 de les pestanyes...
  oferta <- map_dfr(files, read_places) |>
    group_by(year) |>
    summarise(places = sum(places), n_estudis = n(), .groups = "drop")

  demanda <- map_dfr(files, read_applicants) |>
    group_by(year) |>
    summarise(solicitants = sum(solicitants), .groups = "drop")

  # ...i el punt provisional de 2026, encadenat del dossier (vegeu DOSSIER_2026).
  oferta  <- chain_2026(oferta,  "places",      DOSSIER_2026$plc_2026, DOSSIER_2026$plc_2025)
  demanda <- chain_2026(demanda, "solicitants", DOSSIER_2026$sol_2026, DOSSIER_2026$sol_2025)

  pressio <- inner_join(select(oferta, year, places),
                        select(demanda, year, solicitants, provisional), by = "year") |>
    mutate(ratio = solicitants / places)

  # matrícula participants (sèrie completa del fitxer més recent)
  enrol_all <- read_enrolment(latest)
  matricula <- enrol_all |>
    filter(str_detect(universitat, "^Total universitats que participen")) |>
    transmute(year, matricula)

  # notes de tall: 2016-2025 de la pestanya 5.3 (fermes) + 2026 de 1a assignació
  # del PDF de l'OAU (provisional, però sobre la MATEIXA base: també 1a assignació).
  cutoff_2026 <- read_cutoff_2026(file.path(data_dir, "notes_tall_1a_2026.csv"))
  cutoff_raw <- bind_rows(
      mutate(read_cutoff(latest), provisional = FALSE),
      mutate(cutoff_2026,         provisional = TRUE)
    ) |>
    mutate(nota_adj = pmax(nota, CUTOFF_FLOOR))

  notes <- cutoff_raw |>
    group_by(year) |>
    summarise(
      n                  = n(),
      mediana            = median(nota_adj),
      mitjana            = mean(nota_adj),
      q25                = quantile(nota_adj, 0.25),
      q75                = quantile(nota_adj, 0.75),
      n_infrademandats   = sum(nota <= CUTOFF_FLOOR + 1e-6),
      pct_infrademandats = 100 * n_infrademandats / n,
      provisional        = all(provisional),
      .groups = "drop"
    )

  # % d'estudis amb la nota de tall per damunt de cada llindar
  llindars <- map_dfr(CUTOFF_THRESHOLDS, function(t) {
    cutoff_raw |>
      group_by(year) |>
      summarise(llindar = t,
                n_estudis = n(),
                n_sobre = sum(nota_adj >= t),
                pct = 100 * n_sobre / n_estudis,
                provisional = all(provisional),
                .groups = "drop")
  }) |>
    arrange(llindar, year)

  # PAU: resultats agregats de les proves (font externa a Dades_20XX.xlsx)
  pau <- read_pau(file.path(data_dir, "pau_cat_resultats_2010_2025.csv"))

  list(
    oferta = oferta, demanda = demanda, pressio = pressio,
    matricula = matricula, notes = notes, pau = pau, llindars = llindars,
    cutoff_raw = cutoff_raw, enrol_all = enrol_all, files = files
  )
}

# Sèrie llarga unificada (year, metric, value) per exportar / transparència.
tidy_series <- function(s) {
  bind_rows(
    transmute(s$demanda,   year, metric = "solicitants_1a_pref",    value = solicitants),
    transmute(s$oferta,    year, metric = "places",                 value = places),
    transmute(s$pressio,   year, metric = "ratio_sol_plaça",        value = ratio),
    transmute(s$matricula, year, metric = "matricula_nou_acces",    value = matricula),
    transmute(s$notes,     year, metric = "nota_tall_mediana",      value = mediana),
    transmute(s$notes,     year, metric = "nota_tall_mitjana",      value = mitjana),
    transmute(s$notes,     year, metric = "estudis_infrademandats", value = n_infrademandats),
    transmute(s$pau,       year, metric = "pau_presentats",         value = presentats),
    transmute(s$pau,       year, metric = "pau_mitjana_expedient",  value = expedient),
    transmute(s$pau,       year, metric = "pau_mitjana_pau",        value = nota_pau),
    transmute(s$pau,       year, metric = "pau_mitjana_acces",      value = nota_acces),
    transmute(s$llindars,  year, metric = paste0("pct_tall_ge_", llindar), value = pct)
  ) |>
    arrange(metric, year)
}
