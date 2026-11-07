# compile.R <posterior> [attempt]: compile the model and, with an attempt, check
# its config. Exit status 3 means an invalid config.
args <- commandArgs(TRUE)
name <- args[1]
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))
options(warning.length = 8170L)
load_lapland()

info <- posterior_info(name)
materialise(info)
# Fits load build/verified/ directly, because BridgeStan runs make whenever it is
# given a .stan file, and make relinks over a good library if a stray empty .o
# appears beside it. Only a clean build that loads is copied there.
build_library <- function() {
  stem <- sub("\\.stan$", "", info$stan)
  unlink(paste0(stem, c("_model.so", ".o", ".hpp")))
  model <- lapland:::laml_model(info$stan, info$data, 1L)
  dir.create(dirname(info$lib), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(info$lib, ".partial")
  file.copy(paste0(stem, "_model.so"), partial, overwrite = TRUE)
  file.rename(partial, info$lib)
  model
}
model <- if (file.exists(info$lib)) {
  tryCatch(lapland:::laml_model(info$lib, info$data, 1L), error = function(e) {
    message("Rebuilding after load failure: ", conditionMessage(e))
    build_library()
  })
} else {
  build_library()
}
names_unc <- model$param_unc_names()

if (length(args) >= 2) {
  cfg <- read_config(name, args[2])
  outer_idx <- tryCatch(lapland:::get_outer_param_indices(model, cfg$outer), error = function(e) {
    message(conditionMessage(e))
    quit(save = "no", status = 3)
  })
  if (length(outer_idx) >= length(names_unc)) {
    message("Invalid config: at least one parameter must remain inner.")
    quit(save = "no", status = 3)
  }
} else {
  cat("Stan model:", info$pdb_stan, "\n")
  cat("Unconstrained parameters:", length(names_unc), "\n")
  print(names_unc)
}
