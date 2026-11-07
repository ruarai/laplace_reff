# compare.R <posterior> <attempt>: metrics against the reference draws, on the
# constrained scale, for every draw set that exists.
args <- commandArgs(TRUE)
name <- args[1]; attempt <- args[2]
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))

bands <- jsonlite::fromJSON(file.path(root, "bands.json"), simplifyVector = TRUE,
                            simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
chains <- read_zip_json(
  file.path(pdb, "reference_posteriors", "draws", "draws", paste0(name, ".json.zip")),
  simplifyVector = TRUE, simplifyDataFrame = FALSE
)
reference <- do.call(rbind, lapply(chains, function(x) as.data.frame(x, check.names = FALSE)))

run <- run_dir(name, attempt)
metrics <- list(n_reference = nrow(reference), sets = list())

for (set in c("corrected", "uncorrected")) {
  path <- file.path(run, paste0(set, ".rds"))
  if (!file.exists(path)) next
  draws <- readRDS(path)
  missing <- setdiff(names(reference), names(draws))
  if (length(missing) > 0) {
    stop("Reference variables missing from draws: ", paste(missing, collapse = ", "))
  }
  rows <- lapply(names(reference), function(v) {
    c(list(variable = v), variable_metrics(draws[[v]], reference[[v]]))
  })
  mean_err <- vapply(rows, `[[`, 0, "mean_err")
  sd_ratio <- vapply(rows, `[[`, 0, "sd_ratio")
  w1 <- vapply(rows, `[[`, 0, "w1")
  metrics$sets[[set]] <- list(
    label_mean_sd = label_mean_sd(mean_err, sd_ratio, bands$mean_sd),
    label_w1 = label_w1(w1, bands$w1),
    worst_abs_mean_err = max(abs(mean_err)),
    worst_sd_ratio = sd_ratio[which.max(abs(log(sd_ratio)))],
    worst_w1 = max(w1),
    variables = rows
  )
}
write_json(metrics, file.path(attempt_dir(name, attempt), "metrics.json"))
