# Shared paths and helpers. Each script runs in its own R process.
script_dir <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  dirname(normalizePath(sub("^--file=", "", arg[1])))
}
root <- dirname(script_dir())
build <- file.path(root, "build")
results <- Sys.getenv("VALIDATION_RESULTS", file.path(root, "results"))
pdb <- file.path(Sys.getenv("POSTERIORDB", file.path(root, "..", "..", "posteriordb")),
                 "posterior_database")

load_lapland <- function() invisible(loadNamespace("lapland", lib.loc = file.path(build, "lib")))

read_zip_json <- function(path, ...) {
  member <- utils::unzip(path, list = TRUE)$Name[1]
  jsonlite::fromJSON(unz(path, member), ...)
}

posterior_info <- function(name) {
  info <- jsonlite::fromJSON(file.path(pdb, "posteriors", paste0(name, ".json")))
  model <- info$model_name
  list(
    name = name, model = model, data_name = info$data_name,
    pdb_stan = file.path(pdb, "models", "stan", paste0(model, ".stan")),
    pdb_data = file.path(pdb, "data", "data", paste0(info$data_name, ".json.zip")),
    stan = file.path(build, "models", model, paste0(model, ".stan")),
    lib = file.path(build, "verified", model, paste0(model, "_model.so")),
    data = file.path(build, "data", paste0(info$data_name, ".json"))
  )
}

# Copy the model and data under build/, so nothing is written into posteriordb.
materialise <- function(info) {
  dir.create(dirname(info$stan), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(info$data), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(info$stan)) file.copy(info$pdb_stan, info$stan)
  if (!file.exists(info$data)) {
    member <- utils::unzip(info$pdb_data, list = TRUE)$Name[1]
    utils::unzip(info$pdb_data, member, exdir = dirname(info$data), junkpaths = TRUE)
    file.rename(file.path(dirname(info$data), basename(member)), info$data)
  }
}

attempt_dir <- function(name, attempt) file.path(results, name, paste0("attempt-", attempt))
run_dir <- function(name, attempt) {
  dir <- file.path(build, "runs", basename(dirname(results)), name, paste0("attempt-", attempt))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

read_config <- function(name, attempt) {
  cfg <- jsonlite::fromJSON(file.path(attempt_dir(name, attempt), "config.json"),
                            simplifyVector = TRUE, simplifyDataFrame = FALSE,
                            simplifyMatrix = FALSE)
  if (is.null(cfg$inner_control)) cfg$inner_control <- list()
  if (is.null(cfg$outer_control)) cfg$outer_control <- list()
  cfg
}

write_json <- function(x, path) {
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA,
                       na = "null", null = "null")
}

# Run `expr`, collecting warnings instead of printing them.
with_warnings <- function(expr) {
  warnings <- character()
  value <- tryCatch(
    withCallingHandlers(expr, warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    error = function(e) e
  )
  list(value = value, warnings = unique(warnings))
}

# Wasserstein-1 distance between two samples, on a shared quantile grid.
wasserstein1 <- function(x, y, grid = 4000L) {
  u <- (seq_len(grid) - 0.5) / grid
  sx <- sort(x)
  sy <- sort(y)
  mean(abs(sx[ceiling(u * length(sx))] - sy[ceiling(u * length(sy))]))
}

variable_metrics <- function(x, ref) {
  m <- mean(ref)
  s <- stats::sd(ref)
  q <- c(0.05, 0.5, 0.95)
  q_err <- (stats::quantile(x, q, names = FALSE) - stats::quantile(ref, q, names = FALSE)) / s
  list(ref_mean = m, ref_sd = s, laml_mean = mean(x), laml_sd = stats::sd(x),
       mean_err = (mean(x) - m) / s, sd_ratio = stats::sd(x) / s,
       q05_err = q_err[1], q50_err = q_err[2], q95_err = q_err[3],
       w1 = wasserstein1(x, ref) / s)
}

within <- function(value, limits) is.finite(value) && value >= limits[1] && value <= limits[2]

label_mean_sd <- function(mean_err, sd_ratio, bands) {
  pass <- function(band) {
    all(vapply(mean_err, function(e) within(abs(e), c(0, band$abs_mean_err)), TRUE)) &&
      all(vapply(sd_ratio, within, TRUE, band$sd_ratio))
  }
  if (pass(bands$good)) "good" else if (pass(bands$acceptable)) "acceptable" else "poor"
}

label_w1 <- function(w1, bands) {
  pass <- function(band) all(vapply(w1, function(w) within(w, c(0, band$w1)), TRUE))
  if (pass(bands$good)) "good" else if (pass(bands$acceptable)) "acceptable" else "poor"
}
