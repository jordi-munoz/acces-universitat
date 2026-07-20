# =============================================================================
# build_forecast.R
# Projecció de la demanda d'accés a les universitats públiques (2026-2037) a
# partir de les cohorts escolaritzades avui a primària, ESO i batxillerat.
#
# Entrada:  04-output/alumnes_per_ensenyament_nivell.csv  (build_matriculats.R)
#           01-dades/Dades_20XX.xlsx                      (sèrie de sol·licitants)
# Sortida:  04-output/projeccio_demanda.csv
#           04-output/figures/fig_projeccio.png
#
# Ús:  Rscript 02-code/build_forecast.R
# =============================================================================

r_dir <- file.path("02-code", "R")
if (!dir.exists(r_dir)) r_dir <- "R"

source(file.path(r_dir, "read_sheets.R"))
source(file.path(r_dir, "build_series.R"))
source(file.path(r_dir, "forecast_demanda.R"))
source(file.path(r_dir, "plots.R"))

data_dir <- find_data_dir()
out_dir  <- file.path(dirname(data_dir), "04-output")
serie_path <- file.path(out_dir, "alumnes_per_ensenyament_nivell.csv")
if (!file.exists(serie_path)) {
  stop("Falta ", serie_path, ". Executeu abans: Rscript 02-code/build_matriculats.R")
}

serie   <- readr::read_csv(serie_path, show_col_types = FALSE)
coh     <- cohort_table(serie)
s       <- build_all()
demanda <- s$demanda

y <- yield_batx2(demanda, coh)
cat("\n--- Yield sol·licitants / batxillerat 2n del curs anterior ---\n")
print(as.data.frame(mutate(y, yield = round(yield, 4))))
cat("mitjana:", round(mean(y$yield), 4),
    " | recorregut:", round(min(y$yield), 4), "-", round(max(y$yield), 4), "\n")

proj <- forecast_demanda(coh, demanda)

cat("\n--- Projecció ---\n")
print(as.data.frame(proj))

# Sortida tidy: històric + projecció en una sola taula.
taula <- dplyr::bind_rows(
  dplyr::transmute(demanda, year, tipus = "històric", batx2 = NA_real_,
                   solicitants = solicitants, baix = NA_real_, alt = NA_real_,
                   sense_creixement_cohort = NA_real_),
  dplyr::transmute(proj, year, tipus = paste0("projecció (", base, ")"), batx2,
                   solicitants = central, baix, alt, sense_creixement_cohort)
)
csv_path <- file.path(out_dir, "projeccio_demanda.csv")
readr::write_csv(taula, csv_path)
message("Escrit: ", csv_path)

# --- figura ------------------------------------------------------------------
fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

fig_path <- file.path(fig_dir, "fig_projeccio.png")
ggsave(fig_path, plot_projeccio(taula), width = 9, height = 5.4, dpi = 150, bg = "white")
message("Figura: ", fig_path)

# --- resum -------------------------------------------------------------------
ult <- max(demanda$year); ultv <- demanda$solicitants[demanda$year == ult]
fin <- proj[nrow(proj), ]
cat("\n--- Resum ---\n")
cat("Darrer observat:      ", ult, " = ", ultv, " sol·licitants\n", sep = "")
cat("Projecció ", fin$year, ":       ", fin$central,
    " (", round(100 * (fin$central / ultv - 1), 1), "% vs ", ult, ")\n", sep = "")
cat("Escenari sense creixement de cohort ", fin$year, ": ", fin$sense_creixement_cohort,
    " (", round(100 * (fin$sense_creixement_cohort / ultv - 1), 1), "%)\n", sep = "")
