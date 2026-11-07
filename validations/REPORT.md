# lapland validation against posteriordb

Package commit `754026a`, posteriordb commit `91027f9`, run 7 November 2026.
[README.md](README.md) describes the method and the bands.

## Summary

We compared `laml_fit` with reference posteriors on 25 posteriordb models, using
corrected draws. All 23 models that could be built converged on the first attempt,
in 0.33 to 2.07 seconds. Agreement was good on most of them. It failed where the
outer posterior is far from Gaussian on the unconstrained scale.

| Label | Mean/SD | W1 |
|---|---|---|
| Good | 15 | 18 |
| Acceptable | 5 | 3 |
| Poor | 3 | 2 |
| Could not build | 2 | 2 |

Against the predictions made before fitting, using the mean/SD label, 15 matched, 6
did better and 2 did worse. The two ODE models could not be compared.

## Findings

**Stan ODE solvers cannot be used.** `one_comp_mm_elim_abs` (`integrate_ode_bdf`)
and `lotka_volterra` (`integrate_ode_rk45`) fail to compile, because Stan's ODE
solvers do not support the `fvar<var>` needed by `BRIDGESTAN_AD_HESSIAN=true`, and
`laml_model` requires that flag. `lotka_volterra` builds with the flag unset. Four
Stan models in posteriordb use these solvers.

**Poor agreement comes from the Gaussian outer approximation.**
`eight_schools_noncentered`, `accel_gp` and `garch11` are the three poor results,
and the error is worst in the outer variables. In `eight_schools_noncentered`, the
95% quantile of `tau` is 1.56 reference SDs too high. In `accel_gp`, `lscale_sigma_1`
has an SD ratio of 0.51. In `garch11`, `alpha1` is shifted by 0.38 SD. All three fits
converged without warnings, so `converged = TRUE` does not imply that the posterior
is accurate.

**The largest outer SE separated these results.** All three poor results had a
largest outer SE of 0.82 or more on the unconstrained scale, and no other posterior
exceeded 0.58. This pattern was noticed after the results were in, and it rests on
three cases, so it needs testing on other models.

**Small outer scales caused no trouble here.** The documentation warns that outer
SDs much below 1 can stop `nlminb` short of the optimum. Most fits had largest outer
SEs well below 1, down to 0.006 on `radon_all`, and every one passed the convergence
check. This set does not show that the warning is unnecessary, but it did not occur.

**Conditionally Gaussian models work very well.** All 11 linear models took `sigma`
or `sigma_y` as outer. Ten scored good, including `earn_height`, `kilpisjarvi` and
`diamonds`, which were predicted acceptable. `logmesquite_logvas` scored acceptable
on mean/SD and good on W1.

## Results

Values are for corrected draws, taking each posterior's worst variable. Errors and
W1 are in reference SDs. Outer SE is the largest on the unconstrained scale.

| Posterior | Group | Predicted | Mean/SD | W1 | Mean error | SD ratio | W1 value | Outer | Outer SE |
|---|---|---|---|---|---|---|---|---|---|
| [kidiq-kidscore_interaction](results/kidiq-kidscore_interaction/report.md) | linear | good | good | good | 0.06 | 1.05 | 0.07 | `sigma` | 0.034 |
| [earnings-logearn_interaction_z](results/earnings-logearn_interaction_z/report.md) | linear | good | good | good | 0.04 | 1.06 | 0.06 | `sigma` | 0.021 |
| [earnings-earn_height](results/earnings-earn_height/report.md) | linear | acceptable | good | good | 0.02 | 0.95 | 0.05 | `sigma` | 0.021 |
| [mesquite-logmesquite_logvas](results/mesquite-logmesquite_logvas/report.md) | linear | acceptable | acceptable | good | 0.11 | 0.96 | 0.11 | `sigma` | 0.115 |
| [nes2000-nes](results/nes2000-nes/report.md) | linear | good | good | good | 0.06 | 1.05 | 0.06 | `sigma` | 0.033 |
| [radon_mn-radon_pooled](results/radon_mn-radon_pooled/report.md) | linear | good | good | good | 0.02 | 0.96 | 0.05 | `sigma_y` | 0.023 |
| [radon_all-radon_pooled](results/radon_all-radon_pooled/report.md) | linear | good | good | good | 0.03 | 0.95 | 0.06 | `sigma_y` | 0.006 |
| [diamonds-diamonds](results/diamonds-diamonds/report.md) | linear | acceptable | good | good | 0.07 | 1.05 | 0.08 | `sigma` | 0.010 |
| [kilpisjarvi_mod-kilpisjarvi](results/kilpisjarvi_mod-kilpisjarvi/report.md) | linear | acceptable | good | good | 0.08 | 0.95 | 0.08 | `sigma` | 0.092 |
| [sblrc-blr](results/sblrc-blr/report.md) | linear | good | good | good | 0.06 | 0.96 | 0.06 | `sigma` | 0.073 |
| [arK-arK](results/arK-arK/report.md) | linear | good | good | good | 0.07 | 1.04 | 0.07 | `sigma` | 0.052 |
| [eight_schools-eight_schools_noncentered](results/eight_schools-eight_schools_noncentered/report.md) | latent | poor | poor | poor | 0.54 | 1.71 | 0.54 | `tau` | 0.819 |
| [gp_pois_regr-gp_pois_regr](results/gp_pois_regr-gp_pois_regr/report.md) | latent | acceptable | acceptable | acceptable | 0.17 | 0.96 | 0.17 | `rho`, `alpha` | 0.274 |
| [mcycle_gp-accel_gp](results/mcycle_gp-accel_gp/report.md) | latent | acceptable | poor | poor | 0.42 | 0.51 | 0.42 | `sdgp_1`, `lscale_1`, `sdgp_sigma_1`, `lscale_sigma_1` | 0.820 |
| [dogs-dogs_hierarchical](results/dogs-dogs_hierarchical/report.md) | latent | acceptable | good | good | 0.07 | 0.98 | 0.07 | `a` | 0.154 |
| [wells_data-wells_dist100_model](results/wells_data-wells_dist100_model/report.md) | glm | good | good | good | 0.08 | 0.97 | 0.08 | `beta.1` | 0.097 |
| [dogs-dogs](results/dogs-dogs/report.md) | glm | good | good | good | 0.09 | 0.96 | 0.09 | `beta.1` | 0.229 |
| [Rate_2_data-Rate_2_model](results/Rate_2_data-Rate_2_model/report.md) | small | acceptable | acceptable | good | 0.14 | 0.94 | 0.14 | `theta1` | 0.577 |
| [gp_pois_regr-gp_regr](results/gp_pois_regr-gp_regr/report.md) | small | acceptable | good | good | 0.09 | 1.08 | 0.09 | `alpha`, `sigma` | 0.327 |
| [arma-arma11](results/arma-arma11/report.md) | timeseries | acceptable | acceptable | good | 0.13 | 0.95 | 0.13 | `phi`, `theta` | 0.059 |
| [garch-garch11](results/garch-garch11/report.md) | timeseries | acceptable | poor | acceptable | 0.38 | 1.14 | 0.38 | `alpha0`, `alpha1`, `beta1` | 0.985 |
| [one_comp_mm_elim_abs-one_comp_mm_elim_abs](results/one_comp_mm_elim_abs-one_comp_mm_elim_abs/report.md) | ode | poor | not built | not built | n/a | n/a | n/a | n/a | n/a |
| [hudson_lynx_hare-lotka_volterra](results/hudson_lynx_hare-lotka_volterra/report.md) | ode | acceptable | not built | not built | n/a | n/a | n/a | n/a | n/a |
| [low_dim_gauss_mix-low_dim_gauss_mix](results/low_dim_gauss_mix-low_dim_gauss_mix/report.md) | mixture | acceptable | good | good | 0.06 | 0.97 | 0.06 | `sigma.1`, `sigma.2` | 0.039 |
| [hmm_example-hmm_example](results/hmm_example-hmm_example/report.md) | mixture | acceptable | acceptable | acceptable | 0.20 | 1.08 | 0.20 | `theta1.1`, `theta2.1` | 0.327 |

## Limits of this validation

- **Time limits and retries were not exercised by real fits.** The slowest fit took
  2.07 seconds and the slowest corrected draws 40.7 seconds, both on `accel_gp`. No
  attempt was retried, so these paths were tested only with forced failures. The
  largest model has 66 parameters.
- **Each posterior has one outer choice.** Results describe that choice, not the
  best one available. `Rate_2` started at its optimum, so its optimiser made only one
  iteration.
- **Draw noise is shared between some posteriors.** All used the same seed, so
  models with the same dimensions reused random numbers. `earn_height`, `radon_mn`
  and `radon_all` have nearly identical corrected draws after scaling, so their SD
  ratios of about 0.95 are one noisy sample seen three times. For `earn_height`,
  10,000 draws on three seeds gave a `beta[1]` SD ratio of about 0.99, and the
  finite-difference and autodiff `H` agreed to 0.05%. SD ratios within about 0.05 of
  1 should be read as noise on other posteriors too.
- **Only the mean/SD band is sensitive to noise at this size.** It misses good about
  8.5% of the time at 26 variables and 17-23% at 66, under exact agreement. This
  does not affect `accel_gp`, whose errors are far outside the band.
- **`logml` was not validated.** posteriordb has no reference marginal likelihoods.
- **Uncorrected draws are not assessed here.** They score poor on every posterior by
  construction, because outer variables are held fixed.

## Run notes

Three runs failed because of a harness problem, not `lapland`: `diamonds`, `accel_gp`
and `gp_regr` (the last twice). None of them reached a fit, so they were cleared and
rerun with a new subagent. Each rerun chose the same outer set, and all three then
converged on attempt 1.

Empty files with mode `0600` were appearing in the build folder, and the timestamps
suggest this happened just after a command finished. BridgeStan runs `make` each time it loads a `.stan` file, and
`make` then relinked a good library from an empty `.o`. Planting an empty `.o`
reproduced this, down to the exact broken library size. A broken library cannot be
loaded, so no result can have come from one. Attempts now load a verified copy
directly and never run `make`, and no library failures occurred after this change.
The ODE compile errors above are separate and reproducible. **What
creates the empty files is still unknown.** This machine runs several other agent
and editor processes, and none of them was identified as the source.

For the two ODE models, the subagents stopped at `prepare.sh`, so the main session
recorded `attempt-1` to log the compile failure through the harness. The `outer` in
those two configs has no effect. The `lotka_volterra` report originally gave the
cause as unknown, and it now carries a correction.
