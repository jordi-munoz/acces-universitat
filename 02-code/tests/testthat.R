# Executor de proves:  Rscript 02-code/tests/testthat.R
library(testthat)
this <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "02-code/tests")
if (is.null(this) || !nzchar(this)) this <- "02-code/tests"
testthat::test_dir(file.path(this, "testthat"), reporter = "summary", stop_on_failure = TRUE)
