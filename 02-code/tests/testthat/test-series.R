# Proves dels helpers de lectura/agregació: reprodueixen les xifres de referència
# comprovades directament sobre els Excel, i verifiquen que s'exclouen les files
# de secció/subtotal (només estudis amb codi de 5 xifres).
#
# Les xifres àncora són les del sistema *públic*: totes les sèries exclouen els
# estudis exclusius de la UVic-UCC (vegeu is_uvic_only() a build_series.R).

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

test_that("oferta de places: sèrie 2020-2025 i valors àncora", {
  expect_setequal(s$oferta$year, 2020:2025)
  # Totals del full 1.1.5 (40213 el 2020, 41801 el 2025) menys la UVic-UCC.
  expect_equal(get_val(s$oferta, 2020, "places"), 40213 - 2142)
  expect_equal(get_val(s$oferta, 2025, "places"), 41801 - 3070)
  expect_equal(get_val(s$oferta, 2025, "n_estudis"), 555 - 39)
})

test_that("demanda: sol·licitants 1a preferència, valors àncora", {
  expect_equal(get_val(s$demanda, 2020, "solicitants"), 53545)
  expect_equal(get_val(s$demanda, 2025, "solicitants"), 59824)
})

test_that("matrícula de participants: sèrie 2016-2025 i valors àncora", {
  expect_setequal(s$matricula$year, 2016:2025)
  # Total de participants del full 7.5 menys la fila de la UVic-UCC.
  expect_equal(get_val(s$matricula, 2016, "matricula"), 38233 - 1606)
  expect_equal(get_val(s$matricula, 2025, "matricula"), 42090 - 3217)
})

test_that("notes de tall: mediana i estudis infrademandats", {
  expect_equal(get_val(s$notes, 2016, "mediana"), 6.212, tolerance = 1e-3)
  expect_equal(get_val(s$notes, 2025, "mediana"), 8.409, tolerance = 1e-3)
  expect_equal(get_val(s$notes, 2016, "n_infrademandats"), 182)
  expect_equal(get_val(s$notes, 2025, "n_infrademandats"), 119)
})

test_that("pressió: la ràtio sol·licitants/plaça puja de 2020 a 2025", {
  r20 <- get_val(s$pressio, 2020, "ratio")
  r25 <- get_val(s$pressio, 2025, "ratio")
  expect_gt(r25, r20)
  expect_equal(r25, 59824 / 38731, tolerance = 1e-6)
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

test_that("is_uvic_only() distingeix la UVic sola dels estudis compartits", {
  # Noms complets (fulls 1.1.5 i 5.3) i sigles (full 1.1.6).
  expect_true(is_uvic_only("Universitat de Vic-Universitat Central de Catalunya"))
  expect_true(is_uvic_only("UVic-UCC"))
  # Compartits amb una pública: es mantenen.
  expect_false(is_uvic_only(
    "Universitat Autònoma de Barcelona / Universitat de Vic-Universitat Central de Catalunya"))
  # Universitats públiques: no s'hi toca res.
  expect_false(is_uvic_only("Universitat de Barcelona"))
  expect_false(is_uvic_only("UB"))
})

test_that("abast públic: cap sèrie conté estudis exclusius de la UVic-UCC", {
  expect_false(any(is_uvic_only(s$cutoff_raw$universitat)))
  expect_false(any(is_uvic_only(map_dfr(s$files, read_places) |> drop_uvic() |> _$universitat)))
  expect_false(any(is_uvic_only(map_dfr(s$files, read_applicants) |> drop_uvic() |> _$universitat)))
})

test_that("abast públic: els graus compartits UAB/UVic es mantenen", {
  expect_true(any(grepl("Vic", s$cutoff_raw$universitat)))
})

test_that("la UVic-UCC surt dos cops al full 7.5 i només se'n resta la del bloc de participants", {
  vic <- dplyr::filter(s$enrol_all, is_uvic_only(universitat), year == 2025)
  expect_equal(nrow(vic), 2)                      # participants + no participants
  expect_setequal(vic$bloc_participants, c(TRUE, FALSE))
  # Es resta la del bloc de participants (3217), no la de sota (315).
  expect_equal(get_val(s$matricula, 2025, "matricula"), 42090 - 3217)
})

test_that("neteja: només estudis amb codi de 5 xifres (sense subtotals)", {
  raw_places <- read_places(s$files[which.max(year_from_file(s$files))])
  expect_true(all(grepl("^[0-9]{5}$", raw_places$codi)))
  # El total net ha de ser molt inferior a la suma ingènua de 4.4 (que duplica).
  expect_lt(sum(raw_places$places), 100000)
})
