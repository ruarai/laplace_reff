# Code review issues

Review date: 6 November 2026.

## 1. [P2] Numerical gradients depend strongly on parameter units

Location: [R/inner.R:148](R/inner.R#L148).

The gradient calculation forces a fixed coordinate displacement regardless of
parameter scale. Rescaling the existing Poisson model's inner coordinates by
`1e-4` changes an equivalent gradient from approximately `(2.04, 2.91)` to
`(277735, 66977)`, causing optimization failure.

Use scale-aware differentiation steps and expose appropriate controls.

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

## 4. [P2] The gradient tests use an insufficiently accurate reference

Locations: [tests/testthat/test-gradient.R:15](tests/testthat/test-gradient.R#L15)
and [line 23](tests/testthat/test-gradient.R#L23).

These tests differentiate an objective already containing finite-difference
Hessian noise. Five assertions fail in the review environment. Using exact
curvature for the reference reduces every discrepancy below `3e-8`.

Use an analytic or exact-curvature reference to make these checks reliable.

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
