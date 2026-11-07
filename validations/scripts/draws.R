# draws.R <posterior> <attempt>: 4000 uncorrected, then 1000 corrected draws,
# under the 30-minute limit. Each set is saved as soon as it exists.
args <- commandArgs(TRUE)
name <- args[1]; attempt <- args[2]
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))
load_lapland()

info <- posterior_info(name)
run <- run_dir(name, attempt)
fit <- readRDS(file.path(run, "fit.rds"))
fit$model <- lapland:::laml_model(info$lib, info$data, 1L)
summary_path <- file.path(attempt_dir(name, attempt), "draws_summary.json")
summary <- list()

collect <- function(label, n, corrected) {
  start <- proc.time()[["elapsed"]]
  res <- with_warnings(lapland::laml_draws(fit, n, corrected = corrected))
  ok <- !inherits(res$value, "error")
  if (ok) saveRDS(as.data.frame(res$value), file.path(run, paste0(label, ".rds")))
  summary[[label]] <<- list(
    n = n, ok = ok, elapsed_seconds = proc.time()[["elapsed"]] - start,
    warnings = res$warnings,
    error = if (!ok) conditionMessage(res$value)
  )
  write_json(summary, summary_path)
}

set.seed(1)
collect("uncorrected", 4000L, FALSE)
collect("corrected", 1000L, TRUE)
