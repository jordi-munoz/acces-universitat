# Proves del model de projecció de la demanda (forecast_demanda.R).
#
# El que es fixa aquí és sobretot l'alineació temporal, que és on és fàcil
# equivocar-se d'un any i no notar-ho: el batxillerat 2n del curs Y correspon
# als sol·licitants de l'any Y+1 (proves del juny de Y+1).

library(testthat)

find_up <- function(rel, start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(d, rel))) return(file.path(d, rel))
    parent <- dirname(d); if (parent == d) break; d <- parent
  }
  NA_character_
}

source(find_up(file.path("02-code", "R", "forecast_demanda.R")))

# --- cohort_table ------------------------------------------------------------

serie_mostra <- tibble::tribble(
  ~any, ~nom_estudis,                       ~nom_ensenyament,           ~nivell, ~alumnes,
  2024, "EDUCACIÓ PRIMÀRIA",                "EDUCACIÓ PRIMÀRIA",        "1",     100,
  2024, "EDUCACIÓ PRIMÀRIA",                "EDUCACIÓ PRIMÀRIA",        NA,       50,   # sense nivell
  2024, "EDUCACIÓ SECUNDÀRIA OBLIGATÒRIA",  "EDUCACIÓ SECUNDÀRIA OBLIGATÒRIA", "4", 200,
  2024, "BATXILLERAT",                      "BATXILLERAT DE CIÈNCIES",  "2",     300,
  2024, "BATXILLERAT",                      "BATXILLERAT D'ARTS",       "2",      40,
  2024, "EDUCACIÓ D'ADULTS",                "ADAPTACIÓ DE L'ESO",       "1",     999,  # fora
  2024, "EDUCACIÓ ESPECIAL",                "EDUCACIÓ ESPECIAL PRIMÀRIA", "1",   999   # fora
)

test_that("cohort_table() numera els passos de forma contínua per etapa", {
  coh <- cohort_table(serie_mostra)
  expect_equal(coh$pas[coh$alumnes == 100], 1L)    # primària 1r
  expect_equal(coh$pas[coh$alumnes == 200], 10L)   # ESO 4t  = 6 + 4
  expect_equal(PAS_ESO4, 10L)
  expect_equal(PAS_BATX2, 12L)
})

test_that("cohort_table() suma les modalitats de batxillerat en un sol pas", {
  coh <- cohort_table(serie_mostra)
  # Ciències (300) i Arts (40) són el mateix curs: batxillerat 2n = 340.
  expect_equal(coh$alumnes[coh$pas == 12L], 340)
})

test_that("cohort_table() deixa fora adults, especial i files sense nivell", {
  coh <- cohort_table(serie_mostra)
  expect_false(any(coh$alumnes == 999))
  expect_false(any(coh$alumnes == 50))
  expect_equal(sum(coh$alumnes), 100 + 200 + 340)
})

# --- progressió --------------------------------------------------------------

coh_mostra <- tibble::tribble(
  ~any, ~pas, ~alumnes,
  2023,   1L,     100,
  2024,   2L,     110,      # r = 1,10
  2023,   9L,     100,
  2024,  10L,      90       # r = 0,90
)

test_that("progression_ratios() segueix la cohort, no el nivell", {
  r <- progression_ratios(coh_mostra)
  expect_equal(r$r[r$pas == 1L], 1.10)
  expect_equal(r$r[r$pas == 9L], 0.90)
})

test_that("ratios_projeccio() fixa ESO4->BATX1 al darrer valor i la resta a la mitjana recent", {
  cpr <- tibble::tibble(
    pas = rep(c(1L, PAS_ESO4), each = 3),
    any = rep(2022:2024, times = 2),
    r   = c(1.0, 1.0, 1.6,        # pas 1: mitjana dels 3 = 1,2
            0.70, 0.65, 0.60)     # ESO4->BATX1: cau; s'ha d'agafar 0,60
  )
  rr <- ratios_projeccio(cpr, n_recent = 3)
  expect_equal(unname(rr[["1"]]), 1.2)
  expect_equal(unname(rr[["10"]]), 0.60)
})

# --- projected_level ---------------------------------------------------------

test_that("projected_level() prefereix el valor observat quan existeix", {
  out <- projected_level(coh_mostra, c("1" = 99), 2024, 2L, base_any = 2024)
  expect_equal(out$alumnes, 110)
  expect_equal(out$base, "observat")
})

test_that("projected_level() encadena les ràtios quan cal projectar", {
  coh <- tibble::tibble(any = 2025L, pas = 1L, alumnes = 1000)
  r <- c("1" = 1.1, "2" = 1.2)
  out <- projected_level(coh, r, 2027, 3L, base_any = 2025)
  expect_equal(out$alumnes, 1000 * 1.1 * 1.2)
  expect_equal(out$base, "projectat")
})

test_that("projected_level() retorna NULL per a cohorts encara no escolaritzades", {
  coh <- tibble::tibble(any = 2025L, pas = 1L, alumnes = 1000)
  # Batxillerat 2n el 2040 vindria d'un pas negatiu: encara no han començat.
  expect_null(projected_level(coh, c("1" = 1), 2040, PAS_BATX2, base_any = 2025))
})

test_that("ratios_cap_1 limita el creixement de cohort però no la conversió a batxillerat", {
  coh <- tibble::tibble(any = 2025L, pas = 1L, alumnes = 1000)
  r <- setNames(c(rep(1.1, 9), 0.6, 0.9), as.character(1:11))
  amb  <- projected_level(coh, r, 2036, PAS_BATX2, base_any = 2025)
  sense <- projected_level(coh, r, 2036, PAS_BATX2, base_any = 2025, ratios_cap_1 = TRUE)
  expect_lt(sense$alumnes, amb$alumnes)
  # Els passos 10 i 11 (conversions, < 1) s'han de mantenir en tots dos casos.
  expect_equal(sense$alumnes, 1000 * 0.6 * 0.9)
})

# --- alineació temporal del yield --------------------------------------------

test_that("yield_batx2() casa el batxillerat 2n del curs Y amb els sol·licitants de Y+1", {
  coh <- tibble::tibble(any = c(2023L, 2024L), pas = PAS_BATX2, alumnes = c(1000, 2000))
  dem <- tibble::tibble(year = c(2024L, 2025L), solicitants = c(1200, 2600))
  y <- yield_batx2(dem, coh)
  expect_equal(y$batx2[y$year == 2024], 1000)   # curs 2023/2024
  expect_equal(y$yield[y$year == 2024], 1.2)
  expect_equal(y$yield[y$year == 2025], 1.3)
})

# --- xifres àncora sobre la projecció publicada ------------------------------

csv <- find_up(file.path("04-output", "projeccio_demanda.csv"))

test_that("la projecció publicada té la banda ordenada i cobreix 2026-2037", {
  skip_if(is.na(csv), "encara no s'ha generat la projecció")
  p <- readr::read_csv(csv, show_col_types = FALSE)
  pr <- dplyr::filter(p, tipus != "històric")
  expect_setequal(pr$year, 2026:2037)
  expect_true(all(pr$baix <= pr$solicitants))
  expect_true(all(pr$solicitants <= pr$alt))
  # L'escenari sense creixement de cohort mai no pot quedar per damunt del central.
  expect_true(all(pr$sense_creixement_cohort <= pr$solicitants + 1))
})

test_that("la projecció publicada manté el 2026 ancorat a dades observades", {
  skip_if(is.na(csv), "encara no s'ha generat la projecció")
  p <- readr::read_csv(csv, show_col_types = FALSE)
  # Els alumnes de batxillerat 2n del curs 2025/2026 ja estan comptats: la
  # demanda del 2026 no depèn de cap ràtio de progressió.
  expect_equal(p$tipus[p$year == 2026], "projecció (observat)")
  expect_equal(p$batx2[p$year == 2026], 47885)
})

test_that("la projecció descriu un descens sostingut respecte al màxim observat", {
  skip_if(is.na(csv), "encara no s'ha generat la projecció")
  p <- readr::read_csv(csv, show_col_types = FALSE)
  ult_obs <- p$solicitants[p$tipus == "històric" & p$year == 2025]
  fi <- p$solicitants[p$year == 2037]
  expect_lt(fi, ult_obs)
  expect_lt(fi / ult_obs, 0.85)      # caiguda de més del 15%
})
