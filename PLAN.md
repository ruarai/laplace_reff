# Plan: nested Laplace fitting for Stan models

## Goal

Build an R package called "lapland" that takes a Stan model file, data and a list of outer parameter names, and returns an mgcv-style nested fit:

```r
fit <- laml_fit("renewal_model.stan", data, outer = c("alpha", "rho", "log_phi"))
```

The outer parameters are optimised. All other parameters are integrated out with a Laplace approximation at the inner mode. The first test case is the renewal model with a Matern 3/2 HSGP on log R(t).

## Design decisions

- **All parameters stay in the `parameters` block.** There is no moving of parameters to `data`. R holds the outer coordinates fixed in the unconstrained vector, so one compiled model is used throughout.
- **BridgeStan is the backend.** It provides in-process log density, gradient, Hessian, Hessian-vector product, unconstrained names and constrain/unconstrain methods.
- **R owns the inner solver.** `$optimize()` cannot hold a subset fixed, and the outer gradient needs a tightly converged mode.
- **Everything is on Stan's unconstrained scale.** Use `jacobian = TRUE`, so outer priors and their Jacobians come from Stan and are not repeated in R.
- **The objective is LAML, not strict REML.** With proper priors, the result is a Laplace approximate marginal posterior mode. It matches classical REML only when inner fixed effects have flat priors.
- **Default split for the renewal model:** `alpha`, `rho` and `log_phi` are outer. `mu`, `log_i0` and the HSGP weights are inner.

## Method

Let `x` be the inner parameters, `ω` the outer parameters, `ℓ` the log density and `H = -ℓ_xx` at the inner mode `x̂(ω)`.

```
L(ω) = ℓ(x̂, ω) - ½ log|H|
```

Constant terms are dropped because they do not depend on `ω`.

The gradient comes from the implicit function theorem:

```
dx̂/dω_j = H⁻¹ ℓ_xω_j
t_j     = (dx̂/dω_j, e_j)
dL/dω_j = ℓ_ω_j - ½ D_j
```

`D_j` is the directional derivative of `log|H|` along `t_j`.

Inference uses `x ~ N(x̂, H⁻¹)` conditional on `ω̂`. Derived quantities come from passing draws through `param_constrain()`.

## Phases

### Phase 1: Core on BridgeStan

1. Install BridgeStan and build with `BRIDGESTAN_AD_HESSIAN=true`.
2. Map outer parameter names to positions with `param_unc_names()`.
3. Write a damped Newton inner solver, warm-started from the previous mode. Handle a non-positive-definite Hessian explicitly.
4. Compute `L(ω)` and optimise it with Nelder-Mead.

### Phase 2: Outer gradient

Start with directional finite differences, which need no custom C++:

1. Read `ℓ_ω` and `ℓ_xω` from the gradient and full Hessian at `x̂`.
2. Compute `H` at `x̂ ± h t_j` to get `D_j`. This takes two Hessians per outer parameter.
3. Switch the outer optimiser to `nlminb` or BFGS.

**Done when:** the gradient agrees with a finite difference of `L(ω)` at several `ω` values, and the outer loop needs fewer solves than Nelder-Mead.

### Phase 3: Uncertainty

1. Generate `N(x̂, H⁻¹)` draws and pass them through `param_constrain()`.
2. Finite-difference the outer gradient to get the outer Hessian and standard errors for `ω`.
3. Add an option to include outer uncertainty in the intervals, in the style of mgcv's corrected intervals.

**Done when:** conditional and corrected intervals have been compared with HMC.

### Phase 4 (optional): Exact third-order gradient

Do this only if the outer dimension grows or Phase 2 proves too noisy.

Use `stan::math::grad_tr_mat_times_hessian` with `M = H⁻¹` on the inner block to compute `g = ∇ tr(M ℓ_xx)`. Then:

```
dL/dω = ℓ_ω + ½ g_ω + ½ ℓ_ωx H⁻¹ g_x
```

This costs one `g` and one Hessian-vector product, however many outer parameters there are. `model_base` does not expose `fvar<fvar<var>>`, so it needs a small C++ functor calling the templated `log_prob` on `stan_model`. The likely route is appending that functor to the generated C++ and compiling with `Rcpp::sourceCpp`, as cmdstanr does for its model methods. Adding it to BridgeStan would need a fork.

**Done when:** the exact gradient matches Phase 2 and has been timed against it.


## Risks

| Risk | Impact | Response |
|---|---|---|
| Dense inner Hessian | Cost grows quickly with inner dimension, with no sparsity to exploit | Keep the inner dimension to tens or low hundreds |
| Finite-difference noise in the gradient | Outer optimiser stalls | Use the autodiff Hessian, tune `h`, converge the inner solve tightly |
| Non-log-concave likelihood | Inner solve fails, or `H` is not positive definite at intermediate steps | Damping and line search; report any failure at the final mode |
| Multiple inner modes | `L(ω)` jumps between modes under warm starts | Check from several starting values |
| Poor Gaussian approximation | Wrong `log|H|` correction or intervals.| Compare with HMC. |

