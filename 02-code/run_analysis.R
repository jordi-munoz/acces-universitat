# =============================================================================
# run_analysis.R
# Executa tot el pipeline de dades i escriu la sortida a 04-output/:
#   - series_2016_2025.csv  (dades tidy)
#   - figures/*.png         (gràfics)
#
# Ús:  Rscript 02-code/run_analysis.R
# =============================================================================

r_dir <- file.path("02-code", "R")
if (!dir.exists(r_dir)) r_dir <- "R"                      # si es crida des de 02-code/
if (!dir.exists(r_dir)) r_dir <- file.path(dirname(sys.frame(1)$ofile %||% "."), "R")

source(file.path(r_dir, "read_sheets.R"))
source(file.path(r_dir, "build_series.R"))
source(file.path(r_dir, "plots.R"))

s <- build_all()

out_dir <- file.path(dirname(find_data_dir()), "04-output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

csv_path <- file.path(out_dir, "series_2016_2025.csv")
if (requireNamespace("readr", quietly = TRUE)) {
  readr::write_csv(tidy_series(s), csv_path)
} else {
  write.csv(tidy_series(s), csv_path, row.names = FALSE, fileEncoding = "UTF-8")
}

fig_dir <- save_figures(s, out_dir)

message("Escrit: ", csv_path)
message("Figures a: ", fig_dir)
cat("\n--- Sèries ---\n")
print(as.data.frame(tidy_series(s)))
