# Proves de la sèrie d'alumnes matriculats per ensenyament i nivell.
#
# El fitxer d'origen fa ~170 MB i no es versiona, així que les proves es
# reparteixen en dos blocs:
#   - la lògica d'anàlisi i agregació, sobre una mostra petita definida aquí
#     (sempre s'executa, i és on es fixa el comportament);
#   - xifres àncora sobre 04-output/alumnes_per_ensenyament_nivell.csv, que sí
#     que es versiona (es salten si encara no s'ha generat).

library(testthat)

find_up <- function(rel, start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(d, rel))) return(file.path(d, rel))
    parent <- dirname(d); if (parent == d) break; d <- parent
  }
  NA_character_
}

source(find_up(file.path("02-code", "R", "read_matriculats.R")))

# --- anàlisi de xifres -------------------------------------------------------

test_that("parse_num() tracta la coma com a separador de milers, no de decimals", {
  # És l'error que costaria més car: "1,365" són 1365 alumnes. Amb as.numeric()
  # directe seria NA (i es perdrien els centres més grans); amb locale de coma
  # decimal, 1,365.
  expect_equal(parse_num("1,365"), 1365)
  expect_equal(parse_num("9,451"), 9451)
  expect_equal(parse_num("55"), 55)
  expect_equal(parse_num("0"), 0)
  expect_true(is.na(parse_num(NA_character_)))
})

# --- agregació ---------------------------------------------------------------

mostra <- tibble::tibble(
  Curs              = c("2024/2025", "2024/2025", "2024/2025", "2024/2025", "2024/2025"),
  Any               = 2024L,
  `Codi centre`     = c("A", "B", "A", "A", "C"),
  `Nom estudis`     = c("EDUCACIÓ PRIMÀRIA", "EDUCACIÓ PRIMÀRIA", "EDUCACIÓ PRIMÀRIA",
                        "EDUCACIÓ PRIMÀRIA", "FORMACIÓ PROFESSIONAL"),
  `Nom ensenyament` = c("EDUCACIÓ PRIMÀRIA", "EDUCACIÓ PRIMÀRIA", "EDUCACIÓ PRIMÀRIA",
                        "EDUCACIÓ PRIMÀRIA", NA_character_),
  Nivell            = c("1", "1", "2", "1", "1"),
  `Matrícules. Total` = c("10", "1,000", "7", "5", "99"),
  `Matrícules. Dones` = c("6", "600", "3", "2", "50"),
  `Matrícules. Homes` = c("4", "400", "4", "3", "49"),
  Unitats             = c("1", "40", "1", "1", "3")
)

prep <- function(x) {
  dplyr::mutate(x,
    alumnes       = parse_num(`Matrícules. Total`),
    alumnes_dones = parse_num(`Matrícules. Dones`),
    alumnes_homes = parse_num(`Matrícules. Homes`),
    unitats       = parse_num(Unitats))
}

test_that("build_alumnes_nivell() suma per curs, ensenyament i nivell", {
  out <- build_alumnes_nivell(prep(mostra))
  n1 <- dplyr::filter(out, nivell == "1")
  # 10 + 1000 (coma de milers) + 5, sumant els dos centres i les dues files de A.
  expect_equal(n1$alumnes, 1015)
  expect_equal(n1$alumnes_dones, 608)
  expect_equal(n1$unitats, 42)
  # n_centres compta centres únics, no files: A hi surt dues vegades.
  expect_equal(n1$n_centres, 2)
  expect_equal(dplyr::filter(out, nivell == "2")$alumnes, 7)
})

test_that("build_alumnes_nivell() descarta les files sense ensenyament", {
  out <- build_alumnes_nivell(prep(mostra))
  expect_false(any(is.na(out$nom_ensenyament)))
  expect_false("FORMACIÓ PROFESSIONAL" %in% out$nom_estudis)
})

test_that("build_alumnes_nivell() conserva el nivell buit com a categoria pròpia", {
  # Hi ha ensenyaments sense nivell (formació d'adults, idiomes): el NA és
  # informatiu i no s'ha de confondre amb una fila perduda.
  sense_nivell <- dplyr::mutate(mostra[1, ], Nivell = NA_character_)
  out <- build_alumnes_nivell(prep(sense_nivell))
  expect_equal(nrow(out), 1)
  expect_true(is.na(out$nivell))
  expect_equal(out$alumnes, 10)
})

# --- xifres àncora sobre la sortida versionada -------------------------------

csv <- find_up(file.path("04-output", "alumnes_per_ensenyament_nivell.csv"))

test_that("la sèrie publicada té la clau (curs, ensenyament, nivell) única", {
  skip_if(is.na(csv), "encara no s'ha generat la sèrie")
  s <- readr::read_csv(csv, show_col_types = FALSE)
  expect_equal(nrow(s), nrow(dplyr::distinct(s, curs, nom_ensenyament, nivell)))
})

test_that("la sèrie publicada cobreix els 11 cursos i quadra amb el total conegut", {
  skip_if(is.na(csv), "encara no s'ha generat la sèrie")
  s <- readr::read_csv(csv, show_col_types = FALSE)
  expect_setequal(unique(s$curs), paste0(2015:2025, "/", 2016:2026))
  # Total d'alumnes de Catalunya: ~1,5 milions els cursos complets.
  tot <- dplyr::summarise(dplyr::group_by(s, curs), a = sum(alumnes))
  expect_equal(tot$a[tot$curs == "2015/2016"], 1484000)
  expect_equal(tot$a[tot$curs == "2024/2025"], 1493770)
})

test_that("el curs 2025/2026 és incomplet i es pot detectar", {
  skip_if(is.na(csv), "encara no s'ha generat la sèrie")
  s <- readr::read_csv(csv, show_col_types = FALSE)
  cov <- coverage_by_curs(s)
  ult  <- cov[cov$curs == "2025/2026", ]
  prev <- cov[cov$curs == "2024/2025", ]
  # Hi falta gairebé tota la FP i vuit categories senceres: qualsevol
  # comparació amb els cursos anteriors n'ha de tenir en compte el biaix.
  expect_lt(ult$n_estudis, prev$n_estudis)
  fp <- dplyr::filter(s, nom_estudis == "FORMACIÓ PROFESSIONAL")
  expect_lt(sum(fp$alumnes[fp$curs == "2025/2026"]),
            0.1 * sum(fp$alumnes[fp$curs == "2024/2025"]))
})
