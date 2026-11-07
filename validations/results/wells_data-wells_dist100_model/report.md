# wells_data-wells_dist100_model

## Result
Outcome `converged` on attempt 1 of 3 (1 used). Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: both `poor` (by construction). Manifest prediction: `good` (glm, "N=3020 logistic regression: near-Gaussian"). Prediction matched.

## Attempts
1. outer = `beta.1`, alpha inner, default controls. Reasoning: flat priors, 2-parameter logistic GLM, near-Gaussian; either parameter is a valid outer choice. Expected risk: outer SD about 0.1 on the unconstrained scale, well below 1. Outcome `converged`, fit time 0.43 s, nlminb "relative convergence (4)", 5 iterations, distance_sd 8.9e-10, no warnings, outer_se 0.0974.

## Agreement
Corrected draws vs reference: alpha mean error -0.081 SD, SD ratio 0.970, W1 0.085; beta[1] mean error 0.037 SD, SD ratio 0.973, W1 0.047. Location is close and widths are about 3% narrow. The q05 error for beta[1] is 0.15 SD, so the tails differ slightly (small skew). Uncorrected (outer fixed at optimum): alpha SD ratio 0.64, as expected from fixing beta; beta[1] has zero SD by construction.

## Findings
None. The small outer SD (0.1) did not stop nlminb short of the optimum here, and the convergence check passed with a tiny gradient. The roughly 3% narrow SD is probably Laplace/sampling noise, not a package problem.
