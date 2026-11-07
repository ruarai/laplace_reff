# summarise.R: one row per posterior in the manifest, written to results/summary.csv.
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))

manifest <- utils::read.csv(file.path(root, "manifest.csv"))
rows <- lapply(seq_len(nrow(manifest)), function(i) {
  name <- manifest$posterior[i]
  base <- data.frame(posterior = name, group = manifest$group[i], predicted = manifest$predicted[i])
  paths <- Sys.glob(file.path(results, name, "attempt-*", "status.json"))
  if (length(paths) == 0) return(cbind(base, attempts = 0, outcome = "not_run"))
  last <- jsonlite::fromJSON(paths[length(paths)], simplifyVector = TRUE, simplifyDataFrame = FALSE)
  cfg <- read_config(name, last$attempt)
  value <- function(set, field) {
    x <- last$labels[[set]][[field]]
    if (is.null(x)) NA else x
  }
  cbind(base, attempts = length(paths), outcome = last$outcome, draws = last$draws,
        outer = paste(cfg$outer, collapse = " "),
        fit_seconds = if (is.null(last$fit_seconds)) NA else round(last$fit_seconds, 1),
        corrected_mean_sd = value("corrected", "mean_sd"),
        corrected_w1 = value("corrected", "w1"),
        corrected_mean_err = value("corrected", "worst_abs_mean_err"),
        corrected_sd_ratio = value("corrected", "worst_sd_ratio"),
        corrected_worst_w1 = value("corrected", "worst_w1"),
        uncorrected_mean_sd = value("uncorrected", "mean_sd"),
        uncorrected_w1 = value("uncorrected", "w1"))
})
columns <- unique(unlist(lapply(rows, names)))
table <- do.call(rbind, lapply(rows, function(r) {
  r[setdiff(columns, names(r))] <- NA
  r[columns]
}))
utils::write.csv(table, file.path(results, "summary.csv"), row.names = FALSE)
print(table[, intersect(c("posterior", "predicted", "attempts", "outcome", "outer", "fit_seconds",
                          "corrected_mean_sd", "corrected_w1"), columns)], row.names = FALSE)
