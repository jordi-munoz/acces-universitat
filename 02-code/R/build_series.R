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

# L'informe es limita a les universitats *públiques*. La UVic-UCC participa a la
# preinscripció però és de titularitat privada (Fundació Universitària Balmes),
# així que els seus estudis s'exclouen de totes les sèries.
#
# S'exclouen només els estudis on la UVic-UCC és l'única universitat: els graus
# compartits amb una universitat pública (UAB/UVic) es mantenen, perquè els
# imparteix també una pública i perquè al full 7.5 els estudis compartits van
# tots a la fila "Agrupació d'universitats", que no es pot desagregar per
# universitat. Mantenir-los és, doncs, l'únic criteri aplicable a totes les
# sèries per igual.
#
# Les etiquetes són noms complets a 1.1.5 i 5.3 ("Universitat de Vic-...") i
# sigles a 1.1.6 ("UVic-UCC"); la barra marca els estudis compartits.
is_uvic_only <- function(universitat) {
  str_detect(universitat, stringr::fixed("Vic")) & !str_detect(universitat, stringr::fixed("/"))
}

# Treu de la taula els estudis exclusius de la UVic-UCC.
drop_uvic <- function(df) filter(df, !is_uvic_only(universitat))

build_all <- function(data_dir = find_data_dir()) {
  files  <- sort(list.files(data_dir, pattern = "^Dades_20\\d\\d\\.xlsx$", full.names = TRUE))
  latest <- files[which.max(year_from_file(files))]

  # oferta i demanda (un punt per fitxer), només universitats públiques
  oferta <- map_dfr(files, read_places) |>
    drop_uvic() |>
    group_by(year) |>
    summarise(places = sum(places), n_estudis = n(), .groups = "drop")

  demanda <- map_dfr(files, read_applicants) |>
    drop_uvic() |>
    group_by(year) |>
    summarise(solicitants = sum(solicitants), .groups = "drop")

  pressio <- inner_join(select(oferta, year, places), demanda, by = "year") |>
    mutate(ratio = solicitants / places)

  # matrícula participants (sèrie completa del fitxer més recent). El full 7.5
  # no es pot filtrar per estudi: es resta la fila de la UVic-UCC del total de
  # participants (la del bloc de participants, no la del bloc de sota).
  enrol_all <- read_enrolment(latest)
  matricula <- enrol_all |>
    filter(bloc_participants) |>
    group_by(year) |>
    summarise(
      matricula = sum(matricula[str_detect(universitat, "^Total universitats que participen")]) -
                  sum(matricula[is_uvic_only(universitat)]),
      .groups = "drop"
    )

  # notes de tall: resum anual, només universitats públiques
  cutoff_raw <- read_cutoff(latest) |>
    drop_uvic() |>
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
