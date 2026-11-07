# fit.R <posterior> <attempt>: laml_fit under the 10-minute limit.
args <- commandArgs(TRUE)
name <- args[1]; attempt <- args[2]
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))
load_lapland()

info <- posterior_info(name)
cfg <- read_config(name, attempt)
out <- attempt_dir(name, attempt)

start <- proc.time()[["elapsed"]]
res <- with_warnings(lapland::laml_fit(
  info$lib, info$data, cfg$outer,
  inner_control = cfg$inner_control, outer_control = cfg$outer_control, seed = 1L
))
elapsed <- proc.time()[["elapsed"]] - start
fit <- res$value

summary <- list(
  package_sha = trimws(readLines(file.path(build, "package_sha"))),
  outer_requested = cfg$outer, elapsed_seconds = elapsed, warnings = res$warnings
)
if (inherits(fit, "error")) {
  summary$error <- conditionMessage(fit)
  summary$converged <- FALSE
  write_json(summary, file.path(out, "fit_summary.json"))
  quit(save = "no", status = 1)
}

g <- fit$gradient
summary <- c(summary, list(
  converged = fit$converged,
  distance_sd = sqrt(sum(g * (fit$outer_vcov %*% g))),
  n_unconstrained = length(fit$theta),
  outer = as.list(fit$outer),
  outer_se = as.list(fit$outer_se),
  gradient = as.list(g),
  logml = fit$logml,
  counts = as.list(fit$counts),
  nlminb = list(message = fit$opt$message, convergence = fit$opt$convergence,
                iterations = fit$opt$iterations, evaluations = as.list(fit$opt$evaluations))
))
write_json(summary, file.path(out, "fit_summary.json"))

# The model is a live pointer, so draws.R reloads it.
fit$model <- NULL
saveRDS(fit, file.path(run_dir(name, attempt), "fit.rds"))
