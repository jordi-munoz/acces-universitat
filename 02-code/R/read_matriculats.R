# =============================================================================
# read_matriculats.R
# Lectura i agregació del fitxer obert "Alumnes matriculats per ensenyament i
# unitats dels centres docents" (Departament d'Educació i Formació Professional).
#
# El fitxer d'origen és una fila per centre × ensenyament × nivell × modalitat ×
# període de matrícula (~470.000 files, ~170 MB). Aquí es redueix a la sèrie
# demanada: alumnes per ensenyament i nivell, per curs.
#
# Defineix parse_num(), read_matriculats() i build_alumnes_nivell(); no executa
# res en ser carregat. Per generar la sortida: 02-code/build_matriculats.R
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

# Els comptatges de 1.000 o més venen amb coma de milers ("1,365" = 1365). Amb
# as.numeric() directe es convertirien en NA i es perdrien silenciosament les
# xifres més grans (les dels centres més poblats, com Ilerna); amb una locale de
# coma decimal es convertirien en 1,365. Cal treure la coma abans de convertir.
parse_num <- function(x) as.numeric(gsub(",", "", x, fixed = TRUE))

# Llegeix només les columnes necessàries: el fitxer sencer són 36 columnes i
# ~170 MB, i la resta (adreces, coordenades, titularitat...) no intervé aquí.
read_matriculats <- function(path) {
  raw <- read_csv(
    path,
    col_types = cols_only(
      Curs                  = col_character(),
      Any                   = col_integer(),
      `Codi centre`         = col_character(),
      `Nom estudis`         = col_character(),
      `Nom ensenyament`     = col_character(),
      Nivell                = col_character(),
      `Matrícules. Total`   = col_character(),
      `Matrícules. Dones`   = col_character(),
      `Matrícules. Homes`   = col_character(),
      Unitats               = col_character()
    ),
    locale = locale(encoding = "UTF-8"),
    progress = FALSE
  )

  raw |>
    mutate(
      alumnes       = parse_num(`Matrícules. Total`),
      alumnes_dones = parse_num(`Matrícules. Dones`),
      alumnes_homes = parse_num(`Matrícules. Homes`),
      unitats       = parse_num(Unitats)
    )
}

# Agrega a (curs, ensenyament, nivell). Es manté "Nom estudis" perquè cada
# ensenyament en penja d'un i només un (comprovat: 744 ensenyaments, cap
# col·lisió), així que afegir-lo no parteix cap grup i dóna la categoria àmplia
# —FORMACIÓ PROFESSIONAL, EDUCACIÓ PRIMÀRIA...— amb què s'acostuma a agrupar.
#
# Se suma sobre modalitat (presencial, lliure, a distància...) i sobre període
# de matrícula: el detall per centre i per modalitat queda fora de la sèrie.
#
# S'exclouen les files sense "Nom ensenyament": són unitats registrades sense
# ensenyament associat (0 alumnes; 1 en total en tot el fitxer) i, com que un
# mateix NA penja de categories d'estudis diferents, són l'únic cas que trencava
# la unicitat de la clau (curs, ensenyament, nivell). Sense elles, la clau és
# única, que és la propietat que fa la taula utilitzable per fer joins.
build_alumnes_nivell <- function(raw) {
  raw |>
    filter(!is.na(`Nom ensenyament`)) |>
    group_by(
      curs            = Curs,
      any             = Any,
      nom_estudis     = `Nom estudis`,
      nom_ensenyament = `Nom ensenyament`,
      nivell          = Nivell
    ) |>
    summarise(
      alumnes       = sum(alumnes,       na.rm = TRUE),
      alumnes_dones = sum(alumnes_dones, na.rm = TRUE),
      alumnes_homes = sum(alumnes_homes, na.rm = TRUE),
      unitats       = sum(unitats,       na.rm = TRUE),
      n_centres     = n_distinct(`Codi centre`),
      .groups = "drop"
    ) |>
    arrange(curs, nom_estudis, nom_ensenyament, nivell)
}

# Cobertura per curs i categoria d'estudis, per detectar cursos incomplets.
# El curs 2025/2026 del fitxer del 20/07/2026 encara és provisional: hi falta
# gairebé tota la formació professional i vuit categories senceres (vegeu el
# README). Serveix per avisar-ne en construir la sèrie.
coverage_by_curs <- function(serie) {
  serie |>
    group_by(curs) |>
    summarise(
      alumnes     = sum(alumnes),
      n_estudis   = n_distinct(nom_estudis),
      n_ensenyam  = n_distinct(nom_ensenyament),
      .groups = "drop"
    )
}
