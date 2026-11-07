# radon_mn-radon_pooled

## Result
Outcome `converged`, 1 attempt. Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: both `poor` (expected). Manifest prediction: linear, `good` ("Conditionally Gaussian given sigma_y"). The prediction held.

## Attempts
1. outer = `sigma_y`. Given sigma_y, (alpha, beta) is exactly Gaussian. Expected risk: SD of log sigma_y is about 0.02 (N~919), far below 1, with start at 0, so nlminb might stop short. Outcome `converged`, fit time 0.44 s. nlminb: relative convergence, 6 iterations; optimum log sigma_y = -0.2354 (SE 0.0233); distance_sd 4e-10; no warnings.

## Agreement
Corrected: worst abs mean error 0.023 (alpha, in reference-SD units), worst SD ratio 0.956 (alpha; beta 0.960, sigma_y 0.988), worst W1 0.048 (alpha). Locations match; widths are about 1-4% narrow (Laplace on the outer parameter slightly underestimates SD); tails: q05/q95 errors are at most 0.19 SD (sigma_y q95), within sampling noise for 10000 reference draws. Uncorrected draws fix sigma_y at its optimum (SD ratio 0, W1 0.80), which is by construction; alpha and beta mean errors are at most 0.043 SD.

## Findings
None. No warnings, `converged` was TRUE with a tiny gradient, so the feared small-scale early stop did not occur here.
