# Code review issues

Review date: 6 November 2026.

## 1. [P2] Numerical gradients depend strongly on parameter units (resolved)

The steps in `laml_gradient()`, `gradient_hessian()` and `outer_uncertainty()`
are now in posterior standard deviations, set through `inner_control`. The inner
stop is now the Newton decrement, so `tol` is unit-free too. Fits on the Poisson
mock match across inner scales from `1e-6` to `1e6`. This was not checked on the
renewal model; see issue 9.

## 2. [P2] A NaN trial density crashes the solver (resolved)

The line search now rejects nonfinite trial values before comparing them, so
`NaN` and `+Inf` shorten the step. A finite value with a `NaN` gradient still
fails the solve rather than shortening the step.

## 3. [P2] Empty data lists cannot initialize data-free models (resolved)

`stan_json()` now serializes an empty list as `{}`. A compiled data-free model
fits from `list()`.

## 4. [P2] The gradient tests use an insufficiently accurate reference (resolved)

The tests now differentiate `exact_laml()`, which uses exact curvature.

## 5. [P3] Two example calls reference a missing model path (resolved)

## 6. [P3] The comparison script uses an undefined object (resolved)

## 7. [P3] `nlminb` is not unit-free (detected, not fixed)

Location: [R/fit.R](R/fit.R), the `nlminb()` call.

`nlminb` assumes outer posterior standard deviations near 1. On the Poisson mock,
with both outer parameters rescaled to standard deviations of `1e-5` or smaller,
it stops short of the optimum, and it reports success. At `1e5` or larger it
reports false convergence with correct values, so its code is not used.

`converged` now requires `sqrt(g' V g) < 1e-3`, and a failure warns. This
separated wrong fits (`0.14` or above, or `NA`) from correct ones (at most
`3e-5`) on that mock. The threshold was not checked on the renewal model. The
docs advise designing models with unit-scale outer posteriors.

The fit itself still depends on units. `outer_control` cannot fix this: `scale`
is not a control, and it partially matches `scale.init`, which takes one value.
If this needs fixing, passing a finite-difference Hessian and
`scale = sqrt(abs(diag(H)))` to `nlminb()`, with `H` at `init`, fit 223 of 224
mock cases with no silent errors, for about 70% more gradient evaluations.

## 8. [P3] `damped_chol()` has an absolute floor (resolved)

Damping the Hessian with `tau I` depended on units, and the floor could leave
Newton crawling. The smallest `tau` that factorised could also leave `H` nearly
singular, and `max(abs(g))` could report a stationary point far from one. Solves
failed outright, not only on the path: a rotated Cauchy mock converged from 4 of
10 unit sets.

`damped_direction()` now scales `H` to a unit diagonal and uses the magnitudes of
its eigenvalues, and the stop uses the same metric. That mock now converges from
all 10, in 7 iterations each. Only a zero diagonal still uses a fixed scale of 1.
This was not checked on the renewal model.

One limit remains. The first difference step in `inner_newton()` is an absolute
`1e-7`, and it stays in use while `H` has no positive diagonal. At coordinates
near `3e9` it is lost to rounding, so `H` is exactly zero and the solve fails,
wrongly reporting a stationary point.
