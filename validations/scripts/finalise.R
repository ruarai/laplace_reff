# finalise.R <posterior> <attempt> <compile_rc> <fit_rc> <draws_rc>: write status.json.
args <- commandArgs(TRUE)
name <- args[1]; attempt <- args[2]
rc <- as.integer(args[3:5]); names(rc) <- c("compile", "fit", "draws")
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))

dir <- attempt_dir(name, attempt)
read_if <- function(f) {
  path <- file.path(dir, f)
  if (file.exists(path)) jsonlite::fromJSON(path, simplifyVector = TRUE, simplifyDataFrame = FALSE)
}
timed_out <- function(code) code %in% c(124L, 137L)

fit <- read_if("fit_summary.json")
outcome <- if (rc[["compile"]] != 0) {
  "compile_error"
} else if (timed_out(rc[["fit"]])) {
  "fit_timeout"
} else if (rc[["fit"]] != 0) {
  "fit_error"
} else if (isTRUE(fit$converged)) {
  "converged"
} else {
  "not_converged"
}

draws <- if (rc[["draws"]] == -1) {
  "not_run"
} else if (timed_out(rc[["draws"]])) {
  "timeout"
} else if (rc[["draws"]] != 0) {
  "error"
} else {
  "ok"
}

metrics <- read_if("metrics.json")
labels <- lapply(metrics$sets, function(s) {
  list(mean_sd = s$label_mean_sd, w1 = s$label_w1, worst_abs_mean_err = s$worst_abs_mean_err,
       worst_sd_ratio = s$worst_sd_ratio, worst_w1 = s$worst_w1)
})
write_json(list(posterior = name, attempt = as.integer(attempt), outcome = outcome,
                draws = draws, exit_codes = as.list(rc),
                fit_seconds = fit$elapsed_seconds, labels = labels),
           file.path(dir, "status.json"))
