# =============================================================================
# read_sheets.R
# Lectors robustos de les pestanyes rellevants dels fitxers Dades_20XX.xlsx.
#
# Els fulls tenen capçaleres desplaçades i fusionades i files de secció/subtotal
# barrejades amb les dades. L'estratègia comuna:
#   1. Llegir el full sencer com a text (col_names = FALSE, col_types = "text").
#   2. Localitzar files/columnes de capçalera pel seu text.
#   3. Quedar-nos només amb les files de dades reals (codi d'estudi de 5 xifres).
#
# Cada funció retorna un tibble net i llarg. Les xifres de referència comprovades
# es documenten a 02-code/tests/testthat/test-series.R.
# =============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(stringr)
  library(tidyr)
})

# --- utilitats de baix nivell -------------------------------------------------

# Llegeix una pestanya com a matriu de text (sense interpretar capçaleres).
read_raw_matrix <- function(path, sheet) {
  raw <- suppressMessages(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, col_types = "text",
    .name_repair = "minimal"
  ))
  as.matrix(raw)
}

# Índexs (fila, columna) de totes les cel·les que casen amb un patró regex.
grep_cells <- function(m, pattern) {
  hit <- stringr::str_detect(as.vector(m), stringr::regex(pattern, ignore_case = TRUE))
  hit[is.na(hit)] <- FALSE
  which(matrix(hit, nrow = nrow(m)), arr.ind = TRUE)
}

# Columna de la primera cel·la de capçalera que casa amb el patró (o NA).
col_of_header <- function(m, pattern) {
  cells <- grep_cells(m, pattern)
  if (nrow(cells) == 0) return(NA_integer_)
  cells[which.min(cells[, "row"]), "col"]
}

# Fila de la primera cel·la que casa amb el patró (o NA).
row_of_cell <- function(m, pattern) {
  cells <- grep_cells(m, pattern)
  if (nrow(cells) == 0) return(NA_integer_)
  cells[which.min(cells[, "row"]), "row"]
}

# Vector lògic: TRUE si el text és un codi d'estudi de 5 xifres.
is_study_code <- function(x) !is.na(x) & stringr::str_detect(x, "^[0-9]{5}$")

# Extreu l'any (20XX) del nom del fitxer.
year_from_file <- function(path) as.integer(stringr::str_extract(basename(path), "20\\d\\d"))

# --- lectors per pestanya -----------------------------------------------------

# 1.1.5 -> places de preinscripció per estudi (un any = l'any del fitxer).
# Font neta i sense doble comptatge per al total de places (a diferència de 4.4).
read_places <- function(path) {
  m <- read_raw_matrix(path, "1.1.5")
  code_col  <- col_of_header(m, "^Codi$")
  place_col <- col_of_header(m, "Places")
  keep <- is_study_code(m[, code_col])
  tibble(
    year   = year_from_file(path),
    codi   = m[keep, code_col],
    places = suppressWarnings(as.numeric(m[keep, place_col]))
  ) |>
    filter(!is.na(places))
}

# 1.1.6 -> sol·licitants en 1a preferència (juny) per estudi. Columna "Total".
read_applicants <- function(path) {
  m <- read_raw_matrix(path, "1.1.6")
  code_col  <- col_of_header(m, "^Codi$")
  total_col <- col_of_header(m, "^Total$")
  keep <- is_study_code(m[, code_col])
  tibble(
    year        = year_from_file(path),
    codi        = m[keep, code_col],
    solicitants = suppressWarnings(as.numeric(m[keep, total_col]))
  ) |>
    filter(!is.na(solicitants))
}

# 7.5 -> matrícula de nou accés per universitat i any (sèrie 2016-2025 completa
# dins del fitxer més recent). Retorna format llarg amb totes les files.
read_enrolment <- function(path) {
  m <- read_raw_matrix(path, "7.5")
  label_col <- col_of_header(m, "^Universitat de Barcelona$")
  hdr_row   <- row_of_cell(m, "Matr.cula\\s*20\\d\\d")
  year_cells <- grep_cells(m, "Matr.cula\\s*20\\d\\d")
  year_cells <- year_cells[year_cells[, "row"] == hdr_row, , drop = FALSE]
  years     <- as.integer(stringr::str_extract(m[hdr_row, year_cells[, "col"]], "20\\d\\d"))
  y_cols    <- year_cells[, "col"]

  data_rows <- which(!is.na(m[, label_col]) & nzchar(trimws(m[, label_col])))
  data_rows <- data_rows[data_rows > hdr_row]

  purrr_rows <- lapply(data_rows, function(r) {
    vals <- suppressWarnings(as.numeric(m[r, y_cols]))
    tibble(universitat = trimws(m[r, label_col]), year = years, matricula = vals)
  })
  bind_rows(purrr_rows) |>
    filter(!is.na(matricula))
}

# pau_cat_resultats_2010_2025.csv -> resultats agregats de les PAU per convocatòria.
# El curs "2024/25" correspon a les proves de juny de 2025: l'any de la sèrie és
# sempre el segon del curs, que és el que casa amb la preinscripció d'aquell estiu.
read_pau <- function(path) {
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  tibble(
    year        = 2000L + as.integer(stringr::str_extract(raw$Curs_academic, "(?<=/)\\d{2}$")),
    presentats  = as.numeric(raw$Presentats),
    aprovats    = as.numeric(raw$Aprovats),
    expedient   = as.numeric(raw$Mitjana_Expedient),
    nota_pau    = as.numeric(raw$Mitjana_PAU),
    nota_acces  = as.numeric(raw$Mitjana_Acces)
  ) |>
    mutate(bretxa = expedient - nota_pau) |>
    arrange(year)
}

# notes_tall_1a_2026.csv -> notes de tall de 2026 (1a assignació), extretes del
# PDF de l'OAU amb 02-code/extract_notes_tall_pdf.py. La pestanya 5.3 històrica
# també són notes de 1a assignació (comprovat: el 2025 hi casa a la mil·lèsima),
# així que aquest punt amplia la sèrie sobre la mateixa base.
read_cutoff_2026 <- function(path) {
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  tibble(
    codi  = as.character(raw$codi),
    tipus = NA_character_,
    year  = 2026L,
    nota  = as.numeric(raw$nota)
  ) |>
    filter(!is.na(nota))
}

# 5.3 -> notes de tall per estudi i any (sèrie 2016-2025 dins del fitxer recent).
# Buits = estudi no ofert -> NA (exclosos). Retorna format llarg.
read_cutoff <- function(path) {
  m <- read_raw_matrix(path, "5.3")
  code_col  <- col_of_header(m, "^Codi$")
  type_col  <- col_of_header(m, "Tipus")
  hdr_row   <- row_of_cell(m, "^Codi$")
  year_cells <- grep_cells(m, "^20\\d\\d$")
  year_cells <- year_cells[year_cells[, "row"] == hdr_row, , drop = FALSE]
  years  <- as.integer(m[hdr_row, year_cells[, "col"]])
  y_cols <- year_cells[, "col"]

  keep <- which(is_study_code(m[, code_col]))
  rows <- lapply(keep, function(r) {
    vals <- suppressWarnings(as.numeric(m[r, y_cols]))
    tibble(
      codi  = m[r, code_col],
      tipus = if (!is.na(type_col)) trimws(m[r, type_col]) else NA_character_,
      year  = years,
      nota  = vals
    )
  })
  bind_rows(rows) |>
    filter(!is.na(nota))
}
