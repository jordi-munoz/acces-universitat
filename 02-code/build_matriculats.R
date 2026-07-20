# =============================================================================
# build_matriculats.R
# Construeix la sèrie d'alumnes matriculats per ensenyament i nivell, per curs,
# a partir del fitxer obert del Departament d'Educació i Formació Professional.
#
# Entrada:  01-dades/Alumnes_matriculats_per_ensenyament_i_unitats_dels_centres_docents_*.csv
# Sortida:  04-output/alumnes_per_ensenyament_nivell.csv
#
# Ús:  Rscript 02-code/build_matriculats.R
# =============================================================================

r_dir <- file.path("02-code", "R")
if (!dir.exists(r_dir)) r_dir <- "R"

source(file.path(r_dir, "read_matriculats.R"))
source(file.path(r_dir, "build_series.R"))     # find_data_dir()

data_dir <- find_data_dir()
src <- sort(list.files(
  data_dir,
  pattern = "^Alumnes_matriculats_per_ensenyament_i_unitats_dels_centres_docents_.*\\.csv$",
  full.names = TRUE
))
if (!length(src)) stop("No s'ha trobat el CSV d'alumnes matriculats a: ", data_dir)
src <- src[length(src)]                        # el més recent, si n'hi ha més d'un

message("Llegint: ", basename(src), " (pot trigar; ~170 MB)")
raw <- read_matriculats(src)
serie <- build_alumnes_nivell(raw)

out_dir <- file.path(dirname(data_dir), "04-output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
csv_path <- file.path(out_dir, "alumnes_per_ensenyament_nivell.csv")
readr::write_csv(serie, csv_path)

message("Escrit: ", csv_path, " (", nrow(serie), " files)")

# --- avís de cursos incomplets ----------------------------------------------
# El darrer curs del fitxer sol ser provisional. Es compara el nombre de
# categories d'estudis amb el del curs anterior i s'avisa si en falten.
cov <- coverage_by_curs(serie)
print(as.data.frame(cov))

if (nrow(cov) >= 2) {
  ult <- cov[nrow(cov), ]
  prev <- cov[nrow(cov) - 1, ]
  if (ult$n_estudis < prev$n_estudis) {
    warning(
      "El curs ", ult$curs, " és INCOMPLET: ", ult$n_estudis, " categories d'estudis ",
      "davant de ", prev$n_estudis, " el ", prev$curs, ". No el compareu amb els anteriors ",
      "sense filtrar. Vegeu «Alumnes matriculats» al README.",
      call. = FALSE
    )
  }
}
