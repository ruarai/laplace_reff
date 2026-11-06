#' Compile and load a Stan model through BridgeStan
#'
#' @param stan_file Path to a `.stan` file.
#' @param data Named list, JSON string or path to a `.json` file. Wrap
#'   length-one arrays in `I()` so they stay arrays in the JSON.
#' @param seed Seed passed to BridgeStan.
#' @return A `bridgestan::StanModel`.
#' @export
laml_model <- function(stan_file, data, seed = 1L) {
  if (is.list(data)) {
    data <- jsonlite::toJSON(data, auto_unbox = TRUE, digits = NA)
  }

  model <- bridgestan::StanModel$new(
    stan_file, as.character(data), seed,
    make_args = "BRIDGESTAN_AD_HESSIAN=true", warn = FALSE
  )

  # make will not rebuild an up-to-date library, so an old finite-difference
  # build would otherwise be used silently.
  if (grepl("BRIDGESTAN_AD_HESSIAN=false", model$model_info(), fixed = TRUE)) {
    stop("Library was built without BRIDGESTAN_AD_HESSIAN=true. ",
         "Delete the compiled `_model.so` file and try again.", call. = FALSE)
  }
  model
}

# Positions of outer parameters in the unconstrained vector. A name matches
# itself ("z.1") or every element of a container ("z").
outer_index <- function(model, outer) {
  if (length(outer) == 0) stop("`outer` must name at least one parameter.")
  names_unc <- model$param_unc_names()
  stems <- sub("\\..*$", "", names_unc)
  idx <- lapply(outer, function(p) which(names_unc == p | stems == p))
  missing <- outer[lengths(idx) == 0]

  if (length(missing) > 0) {
    stop("Unknown outer parameter(s): ", paste(missing, collapse = ", "),
         ". Unconstrained names are: ", paste(names_unc, collapse = ", "))
  }
  
  idx <- unlist(idx)
  if (anyDuplicated(idx)) stop("`outer` names a parameter more than once.")
  if (length(idx) == length(names_unc)) {
    stop("`outer` covers every parameter, leaving nothing to integrate out.")
  }
  idx
}
