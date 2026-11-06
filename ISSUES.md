# Code review issues

Review date: 6 November 2026.

## 1. [P2] Numerical gradients depend strongly on parameter units (resolved)

The steps in `laml_gradient()`, `gradient_hessian()` and `outer_uncertainty()`
are now in posterior standard deviations, set through `inner_control`. The inner
stop is now the Newton decrement, so `tol` is unit-free too. Fits on the Poisson
mock match across inner scales from `1e-6` to `1e6`. This was not checked on the
renewal model; see issue 9.

## 2. [P2] A NaN trial density crashes the solver

Location: [R/inner.R:106](R/inner.R#L106).

The line search passes the density comparison directly to `if`. A compiled Stan
model returning `NaN` produces "missing value where TRUE/FALSE needed," aborting
fitting instead of shortening the step.

Reject nonfinite trial values before comparing them.

## 3. [P2] Empty data lists cannot initialize data-free models

Location: [R/model.R:115](R/model.R#L115).

The data serializer converts `list()` to `[]`. BridgeStan rejects this with
"Expecting JSON object, found array." The same compiled model fits successfully
with `"{}"`.

Serialize an empty data list as an object.

## 4. [P2] The gradient tests use an insufficiently accurate reference (resolved)

The tests now differentiate `exact_laml()`, which uses exact curvature.

## 5. [P3] Two example calls reference a missing model path

Locations: [scratch/renewal_run.R:40](scratch/renewal_run.R#L40) and
[scratch/renewal_compare.R:74](scratch/renewal_compare.R#L74).

These calls still load `inst/model_renewal.stan`; the file resides under
`scratch/`. The missing path prevents the examples from completing.

Update both calls to use `scratch/model_renewal.stan`.

## 6. [P3] The comparison script uses an undefined object

Location: [scratch/renewal_compare.R:123](scratch/renewal_compare.R#L123).

The script calls `compare(corrected, ...)`, but the assignment to `corrected` is
commented out. A fresh session fails here; an interactive session could
accidentally compare stale draws.

Generate the draws or make both operations conditional.

## 7. [P3] `nlminb` is not unit-free

Location: [R/fit.R](R/fit.R), the `nlminb()` call.

Rescaling the outer parameters by `1e4` or more can report `converged = FALSE`
with correct values, and `1e-6` reaches the wrong optimum. `outer_control` can
pass `scale` to `nlminb()`, though nothing sets it automatically.

## 8. [P3] `damped_chol()` has an absolute floor

Location: [R/inner.R](R/inner.R), `damped_chol()`.

`tau` uses `max(1, abs(diag(H)))`, which depends on units. It only affects the
path taken while `H` is not positive definite, not the mode found.

## 9. [P2] The Newton decrement stop is untested on real models

Location: [R/inner.R](R/inner.R), `inner_newton()`.

The decrement cannot fall below roughly gradient noise x SD x sqrt(n). A weakly
identified model might not reach the default `tol`, and solves that passed under
`max(abs(g)) < tol` would then return `-Inf`. Fit the renewal model before and
after this change to find out. Raising `tol` is the workaround.

## Validation

- Ran the full test suite, including compiled Stan tests. Five assertions failed,
  all described in issue 4.
- Package build succeeded.
- `R CMD check --no-tests --no-manual` completed with one note about the bundled
  `.review` directory.
- Additional checks of correlated Gaussian models, reordered outer parameters,
  and corrected-draw covariance passed.
- The expensive scratch HMC workflow was not executed.
- No repository files were changed during the review. This document records the
  findings; it does not implement fixes.
