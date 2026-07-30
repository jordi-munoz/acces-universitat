# Proves dels helpers de lectura/agregació: reprodueixen les xifres de referència
# comprovades directament sobre els Excel, i verifiquen que s'exclouen les files
# de secció/subtotal (només estudis amb codi de 5 xifres).

library(testthat)

# Localitza 02-code/R pujant des del directori de treball i carrega el codi.
find_up <- function(rel, start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (dir.exists(file.path(d, rel))) return(file.path(d, rel))
    parent <- dirname(d); if (parent == d) break; d <- parent
  }
  stop("No s'ha trobat: ", rel)
}

r_dir <- find_up(file.path("02-code", "R"))
source(file.path(r_dir, "read_sheets.R"))
source(file.path(r_dir, "build_series.R"))

s <- build_all()

get_val <- function(df, yr, col) df[[col]][df$year == yr]

test_that("oferta de places: sèrie 2020-2025 (ferma) + 2026 provisional", {
  expect_setequal(s$oferta$year, 2020:2026)
  expect_equal(get_val(s$oferta, 2020, "places"), 40213)
  expect_equal(get_val(s$oferta, 2025, "places"), 41801)
  expect_equal(get_val(s$oferta, 2025, "n_estudis"), 555)
  # el 2026 és l'únic any marcat com a provisional
  expect_setequal(s$oferta$year[s$oferta$provisional], 2026)
  expect_false(any(s$oferta$provisional[s$oferta$year <= 2025]))
})

test_that("2026 provisional: enllaçat del dossier sobre el nivell ferm de 2025", {
  # el punt de 2026 no es copia del dossier: s'encadena la seva variació
  # interanual sobre el valor "al tancament" de 2025 de la sèrie pròpia.
  expect_equal(get_val(s$demanda, 2026, "solicitants"),
               round(63038 * DOSSIER_2026$sol_2026 / DOSSIER_2026$sol_2025))
  expect_equal(get_val(s$oferta, 2026, "places"),
               round(41801 * DOSSIER_2026$plc_2026 / DOSSIER_2026$plc_2025))
  expect_true(get_val(s$demanda, 2026, "provisional"))
  # la ràtio de 2026 hereta la marca de provisional
  expect_true(get_val(s$pressio, 2026, "provisional"))
})

test_that("demanda: sol·licitants 1a preferència, valors àncora", {
  expect_equal(get_val(s$demanda, 2020, "solicitants"), 55815)
  expect_equal(get_val(s$demanda, 2025, "solicitants"), 63038)
})

test_that("matrícula de participants: sèrie 2016-2025 i valors àncora", {
  expect_setequal(s$matricula$year, 2016:2025)
  expect_equal(get_val(s$matricula, 2016, "matricula"), 38233)
  expect_equal(get_val(s$matricula, 2025, "matricula"), 42090)
})

test_that("notes de tall: mediana i estudis infrademandats", {
  expect_equal(get_val(s$notes, 2016, "mediana"), 5.924, tolerance = 1e-3)
  expect_equal(get_val(s$notes, 2025, "mediana"), 8.203, tolerance = 1e-3)
  expect_equal(get_val(s$notes, 2016, "n_infrademandats"), 206)
  expect_equal(get_val(s$notes, 2025, "n_infrademandats"), 138)
})

test_that("pressió: la ràtio sol·licitants/plaça puja de 2020 a 2025", {
  r20 <- get_val(s$pressio, 2020, "ratio")
  r25 <- get_val(s$pressio, 2025, "ratio")
  expect_gt(r25, r20)
  expect_equal(r25, 63038 / 41801, tolerance = 1e-6)
})

test_that("PAU: l'any de la sèrie és el de les proves, no el d'inici del curs", {
  # 2010/11 -> 2011 (proves del juny de 2011); 2025/26 -> 2026.
  expect_setequal(s$pau$year, 2011:2026)
  expect_equal(get_val(s$pau, 2011, "presentats"), 24152)
  expect_equal(get_val(s$pau, 2026, "presentats"), 34642)
  # Àncora del canvi de model: el juny de 2025 la mitjana de la prova cau.
  expect_equal(get_val(s$pau, 2025, "nota_pau"), 6.453, tolerance = 1e-3)
  expect_lt(get_val(s$pau, 2025, "nota_pau"), get_val(s$pau, 2024, "nota_pau"))
})

test_that("PAU: la nota d'accés és 60% expedient + 40% prova", {
  expect_equal(s$pau$nota_acces, 0.6 * s$pau$expedient + 0.4 * s$pau$nota_pau,
               tolerance = 5e-3)
})

test_that("neteja: només estudis amb codi de 5 xifres (sense subtotals)", {
  raw_places <- read_places(s$files[which.max(year_from_file(s$files))])
  expect_true(all(grepl("^[0-9]{5}$", raw_places$codi)))
  # El total net ha de ser molt inferior a la suma ingènua de 4.4 (que duplica).
  expect_lt(sum(raw_places$places), 100000)
})
