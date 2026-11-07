# garch-garch11

## Result
Outcome `converged` after 1 attempt. Corrected draws: mean_sd `poor`, w1 `acceptable`. Uncorrected: mean_sd `poor`, w1 `poor`. Manifest prediction: `acceptable` ("Constrained volatility parameters near boundaries").

## Attempts
1. outer = alpha0, alpha1, beta1 (inner = mu). mu is a location parameter, close to Gaussian given the volatility parameters; the three bounded volatility parameters interact nonlinearly so they were outer. Expected risks: unconstrained SDs differing from 1, a start at zero far from the mode, and skew near the boundaries. Outcome `converged`, fit time 0.35 s, no warnings, distance_sd 2.4e-7, 8 nlminb iterations. Outer SEs on the unconstrained scale: 0.43, 0.55, 0.99, so scales were reasonable.

## Agreement
Error columns (mean_err, q*_err) are in reference SD units. Corrected draws:
- alpha1 (worst): mean err -0.38 SD, w1 0.38, q05 -0.52, q50 -0.30, q95 -0.52. LAML is shifted low by about 0.05 in raw units (0.519 vs 0.567). Width is right (sd ratio 1.02), so this is a location shift.
- beta1: mean +0.11 SD, sd ratio 1.07, q95 +0.45, so the upper tail is heavier or longer than the reference.
- alpha0: mean +0.10 SD, sd ratio 1.14 (widest mismatch), q95 +0.49, q50 about 0, so the right tail is too long. The posterior is skewed on the constrained scale and the Gaussian-on-unconstrained approximation does not fully capture it.
- mu: mean -0.13 SD, sd ratio 1.01. Fine.
Uncorrected draws (outer fixed at optimum): worst sd ratio 0 and worst w1 0.84 for the outer variables, as expected by construction. mu is close (mean err -0.08 SD, sd ratio 0.99).

## Findings
No warnings and no suspicious `converged`. The remaining error is the approximation's limitation: a Gaussian on the unconstrained outer parameters cannot represent the skewed, boundary-constrained marginal of alpha1/alpha0/beta1. The alpha1 location shift (-0.38 SD) may reflect the outer mode differing from the posterior mean on the constrained scale. I have no evidence of a package bug.
