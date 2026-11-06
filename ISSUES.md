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

## 3. [P2] Empty data lists cannot initialize data-free models (resolved)

`stan_json()` now serializes an empty list as `{}`. A compiled data-free model
fits from `list()`.

## 4. [P2] The gradient tests use an insufficiently accurate reference (resolved)

The tests now differentiate `exact_laml()`, which uses exact curvature.

## 5. [P3] Two example calls reference a missing model path (resolved)

## 6. [P3] The comparison script uses an undefined object (resolved)

## 7. [P3] `nlminb` is not unit-free

Location: [R/fit.R](R/fit.R), the `nlminb()` call.

Rescaling the outer parameters by `1e4` or more can report `converged = FALSE`
with correct values, and `1e-6` reaches the wrong optimum. `outer_control` can
pass `scale` to `nlminb()`, though nothing sets it automatically.

## 8. [P3] `damped_chol()` has an absolute floor

Location: [R/inner.R](R/inner.R), `damped_chol()`.

`tau` uses `max(1, abs(diag(H)))`, which depends on units. It only affects the
path taken while `H` is not positive definite, not the mode found.