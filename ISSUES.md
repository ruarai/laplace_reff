# Code review issues

Reviewed 7 November 2026 at commit `754026a`, including the working tree.
All six issues are open. P1 indicates a high-priority correctness issue, P2 a
numerical or API limitation, and P3 a maintenance issue.

## 1. [P1] Edited Stan models can silently reuse the old compiled model

Location: `R/model.R:5–10` (`laml_model`).

The model loader passes `warn = FALSE` to BridgeStan. This suppresses its warning
that a shared library is already loaded and that recompiling the same path may
not update the model in the current R session.

**Reproduction:** fit a model with `m ~ normal(1, 1)` and `x ~ normal(m, 1)`, using
`m` as the outer parameter. Change the first prior to `m ~ normal(5, 1)` and fit
the same Stan path again in the same session. The second fit still estimates
`m = 1`, without warning. Fitting the edited file in a fresh R session returns
`m = 5`, confirming that the rebuilt library contains the change.

**Impact:** iterative model development can produce apparently successful fits
for an earlier version of the model.

**Suggested fix:** load changed models from distinct compiled-library paths,
with cache identity accounting for source, included files and compiler settings.
Preserve the validity of existing fit objects; blindly unloading their library
is unsafe. Restore BridgeStan's warning until changed-model loading is handled.

**Regression coverage:** change and refit a Stan file within one R process;
verify that the new fit reflects the change and that the old fit remains usable.

## 2. [P1] A singular exact inner Hessian can yield a converged fit with invalid uncertainty

Location: `R/inner.R:210–224` (`exact_mode`), particularly the fallback at lines
217–220. Related: `inner_newton` and the outer-only convergence check in
`R/fit.R:96–99`.

The fallback conflates two cases: failure to evaluate the autodiff Hessian, and
successful evaluation showing that the inner precision is singular or
indefinite. In the second case, the finite-difference Hessian can spuriously be
positive definite. Returning it conceals evidence that the ordinary Gaussian
Laplace approximation is invalid at this point.

**Reproduction:** compile this Stan model and call
`laml_fit(path, list(), outer = "w")`:

```stan
parameters {
  real x;
  real w;
}
model {
  target += -square(square(x)) - 0.5 * square(w);
}
```

The mode is `(x, w) = (0, 0)`, and the exact inner precision is zero. The observed
fit nevertheless returned `converged = TRUE`, `H = 10000`, and `logml` about
`-4.60517`, with only the warning that autodiff had failed and finite differences
were being used. Its conditional draws have variance `0.0001`; the actual
variance under a density proportional to `exp(-x^4)` is approximately `0.338`.
The latter comparison illustrates the bad result; there is no valid ordinary
Gaussian Laplace covariance at this mode.

Repeated calls to the internal objective at the same outer value also alternated
between approximately `15.42495` and `-4.60517`. The adaptive difference steps
oscillate because curvature is being estimated at a genuinely flat mode.

**Suggested fix:** distinguish an unavailable Hessian from a finite exact
Hessian that fails positive-definiteness. Reject the latter as an invalid
Laplace mode, or return an explicitly unusable result that prevents posterior
draws. A warning about an evaluation failure is not an adequate diagnosis.

**Regression coverage:** the compiled model above must not return a usable,
converged fit. Keep separate coverage for a genuine autodiff evaluation error
where the documented finite-difference fallback is intended.

### Practical relevance

The quartic example is a minimal reproducer, not evidence that this failure is
common in well-identified, regularized models. There are realistic sources of
singular curvature:

- **Factor analysis, probabilistic PCA and latent matrix factorization.** With
  two or more factors, rotationally invariant priors can preserve a continuous
  family of equivalent parameter values even when all priors and the posterior
  are proper. At a nonzero stationary mode, a direction along that family has
  zero curvature. This makes the *inner* Hessian singular when the inner block
  contains the parameters needed to perform the rotation. Rotational posterior
  symmetry and its treatment in Stan are discussed by
  [Nirwan and Bertschinger (2019)](https://arxiv.org/abs/1905.04720).
- **Unidentified regression and hierarchical models.** Redundant intercepts,
  exactly collinear predictors, and unanchored ability/difficulty parameters
  can leave flat directions when the priors do not identify them. These cases
  often have an improper posterior; proper identifying priors or constraints
  can remove the singularity. See the
  [Stan User's Guide on problematic posteriors](https://mc-stan.org/docs/stan-users-guide/label-switching-problematic.html).

A small latent-factor example makes the first case explicit:

```stan
data {
  real y;
}
parameters {
  vector[2] a;
  vector[2] b;
  real log_sigma;
}
model {
  a ~ std_normal();
  b ~ std_normal();
  log_sigma ~ std_normal();
  y ~ normal(dot_product(a, b), exp(log_sigma));
}
```

Take `a` and `b` as inner parameters and fix outer `log_sigma = 0`. With `y = 2`,
`a = b = (1, 0)` is a conditional mode. Rotating both vectors together preserves
the dot product and both prior densities. The negative inner Hessian has
eigenvalues `2, 2, 2, 0`. This calculation follows directly from this example;
the small model illustrates the same symmetry present in larger factor models.
Its proper normal priors do not remove rotational invariance.

Direct evaluation with BridgeStan confirmed a zero inner gradient and precision
eigenvalues `2, 2, 2, 1.11e-15` (the last is zero to numerical precision). Joint
rotations preserved the evaluated log density. This checks curvature at a known
conditional mode; the quartic example above is the end-to-end reproduction of
the erroneous fallback.

A singular *joint* Hessian does not automatically imply a singular *inner*
Hessian: fixing outer parameters may remove the problematic direction. Nearly
singular curvature is also distinct from exact singularity. The issue here is
reporting usable inference after exact curvature has invalidated the local
Gaussian approximation, not a requirement to support every unidentified model.
The review did not establish singular curvature in the renewal example.

## 3. [P2] The initial Hessian step breaks the documented rescaling behavior

Location: `R/inner.R:232` (`make_objective`), and `R/inner.R:98–111`
(`inner_newton`).

Every objective starts with an absolute difference step of `1e-7`. The
curvature-scaled `hessian_step` takes effect only after a Hessian has already
been evaluated successfully.

**Reproduction:** use the existing test helpers to rescale all six inner
coordinates of `poisson_mock(c(0, 1, 2, 4, 7, 12))` by `1e10`, leaving its outer
coordinates unchanged. The unscaled model fits successfully; the equivalent
rescaled model fails at initialization with a non-finite gradient or Hessian.
The initial stencil crosses a region where exponentials overflow. Changing
`inner_control$hessian_step` cannot change this first stencil.

**Impact:** sufficiently narrow inner scales can prevent fitting despite valid
derivatives at the starting point and the documented rescaling behavior. This
reproducer uses an extreme scale; it does not establish failure for ordinary
parameter scales.

**Suggested fix:** adapt the initial stencil when evaluations fail, obtain a
usable initial scale, or expose initial coordinate step sizes.

**Regression coverage:** an equivalent rescaled model whose initial stencil
overflows should recover through step adaptation, or give an actionable error
with an available initialization control.

## 4. [P2] Mandatory zero initialization makes some valid models impossible to fit

Location: `R/fit.R:59–67` (`fit_model`), and the public `laml_fit` arguments.

Every unconstrained parameter starts at zero. There is no public initial-value
argument or initialization retry.

**Reproduction:** for the smooth, proper log density
`-(x^2 - 1)^2 - w^2 / 2`, with `w` outer, the zero start is a stationary minimum
in `x`. Fitting fails with “H is not positive definite at a stationary point”.
Calling the inner solver with `x = 1` succeeds. Valid models whose density is
undefined at the zero start encounter the same API limitation.

**Suggested fix:** expose initial values and pass them through to the fitting
implementation. Constrained initialization can use BridgeStan's unconstraining
methods. Optional retries may improve robustness but do not replace a user
override.

**Regression coverage:** a model that fails from zero should fit from explicitly
supplied valid initial values.

## 5. [P3] The renewal example references a missing model path

Location: `scratch/renewal_run.R:40`.

The script calls `laml_fit("inst/model_renewal.stan", ...)`, but the repository's
model is at `scratch/model_renewal.stan`. There is no corresponding `inst` file.
The script fails at its fitting step when run from the repository root.

**Suggested fix:** use the existing model path.

## 6. [P3] Internal review files are included in the source package

Location: `.Rbuildignore`.

The build exclusions do not cover `.review`. The source package contains
internal review material, and `R CMD check` reports a NOTE about this hidden
directory.

**Suggested fix:** exclude `.review` from the package build. Check which other
development-only review documents should also be excluded.

**Validation:** build the source package and verify that internal review files
are absent and the associated check NOTE is resolved.

## Review validation and limits

- Reviewed package source, tests, documentation, configuration and scratch
  scripts. The pre-existing edit to `scratch/renewal_compare.R` was preserved.
- The existing suite contained 60 test cases and passed 199 assertions with
  zero failures, warnings or skips, including compiled Stan integration tests.
- The source-package build succeeded.
- `R CMD check --no-manual --no-build-vignettes` completed with zero errors,
  zero warnings and one NOTE, described in issue 6. These results precede the
  addition of this issue document.
- Both P1 findings were reproduced with compiled Stan models. Numerical/API
  probes also used the repository's mock-model helpers.
- Execution used Linux, R 4.6.1 and BridgeStan 2.9.0. The expensive renewal/HMC
  comparison was inspected but not run. Other platforms and dependency versions
  were not tested.
