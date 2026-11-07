# Compile and load a Stan model through BridgeStan. `data` is as in laml_fit().
laml_model <- function(stan_file, data, seed = 1L) {
  if (is.list(data)) data <- stan_json(data)

  model <- suppress_long_path_warning(bridgestan::StanModel$new(
    stan_file, as.character(data), seed,
    stanc_args = paste0("--include-paths=", dirname(normalizePath(stan_file))),

    make_args = "BRIDGESTAN_AD_HESSIAN=true", warn = FALSE
  ))

  # make will not rebuild an up-to-date library, so an old finite-difference
  # build would otherwise be used silently.
  if (grepl("BRIDGESTAN_AD_HESSIAN=false", model$model_info(), fixed = TRUE)) {
    stop("Library was built without BRIDGESTAN_AD_HESSIAN=true. ",
         "Delete the compiled `_model.so` file and try again.", call. = FALSE)
  }
  model
}

# BridgeStan calls tools::file_ext() on `data`, and basename() warns when a JSON
# string is too long to be a path. The string is still used correctly.
suppress_long_path_warning <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (startsWith(conditionMessage(w), "expanded path length")) {
      invokeRestart("muffleWarning")
    }
  })
}

# Positions of outer parameters in the unconstrained vector. A name matches
# itself ("z.1") or every element of a container ("z").
# TODO: change this so that it matches normal indexing notation rather than
# bridgestan's weird version.
get_outer_param_indices <- function(model, outer) {
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

# stan_json() and list_to_array() are copied from cmdstanr 0.9.0
# (https://github.com/stan-dev/cmdstanr). The only changes are that
# write_stan_json() became stan_json(), which returns the JSON as a string
# instead of writing a file, that an empty list gives "{}" rather than "[]", and
# that `%||%` in list_to_array() is written out, as it needs R >= 4.4. cmdstanr's
# licence applies to these two functions:
#
# Copyright (c) 2019, Stan Developers and their Assignees
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
stan_json <- function(data, always_decimal = FALSE) {
  if (!is.list(data)) {
    stop("'data' must be a list.", call. = FALSE)
  }

  # toJSON() writes an unnamed empty list as an array, which Stan rejects.
  if (length(data) == 0) return("{}")

  data_names <- names(data)
  if (length(data) > 0 &&
      (length(data_names) == 0 ||
       length(data_names) != sum(nzchar(data_names)))) {
    stop("All elements in 'data' list must have names.", call. = FALSE)
  }
  if (anyDuplicated(data_names) != 0) {
    stop("Duplicate names not allowed in 'data'.", call. = FALSE)
  }

  for (var_name in data_names) {
    var <- data[[var_name]]
    if (!(is.numeric(var) || is.factor(var) || is.logical(var) ||
          is.data.frame(var) || is.list(var))) {
      stop("Variable '", var_name, "' is of invalid type.", call. = FALSE)
    }
    if (anyNA(var)) {
      stop("Variable '", var_name, "' has NA values.", call. = FALSE)
    }

    if (is.table(var)) {
      var <- unclass(var)
    } else if (is.logical(var)) {
      mode(var) <- "integer"
    } else if (is.data.frame(var)) {
      var <- data.matrix(var)
    } else if (is.list(var)) {
      var <- list_to_array(var, var_name)
    }
    data[[var_name]] <- var
  }

  jsonlite::toJSON(
    data,
    auto_unbox = TRUE,
    factor = "integer",
    always_decimal = always_decimal,
    digits = NA,
    pretty = TRUE
  )
}

list_to_array <- function(x, name = NULL) {
  list_length <- length(x)
  if (list_length == 0) {
    return(NULL)
  }
  all_dims <- lapply(x, function(z) if (is.null(dim(z))) length(z) else dim(z))
  all_equal_dim <- all(sapply(all_dims, function(d) {
    isTRUE(all.equal(d, all_dims[[1]]))
  }))
  if (!all_equal_dim) {
    stop("All matrices/vectors in list '", name, "' must be the same size!",
         call. = FALSE)
  }
  all_numeric <- all(sapply(x, function(a) is.numeric(a)))
  if (!all_numeric) {
    stop("All elements in list '", name, "' must be numeric!", call. = FALSE)
  }
  element_num_of_dim <- length(all_dims[[1]])
  x <- unlist(x)
  dim(x) <- c(all_dims[[1]], list_length)
  aperm(x, c(element_num_of_dim + 1L, seq_len(element_num_of_dim)))
}
