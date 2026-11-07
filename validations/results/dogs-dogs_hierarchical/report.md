# dogs-dogs_hierarchical

## Result
Outcome `converged`, 1 attempt used. Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: both `poor` (expected, outer held fixed). Manifest prediction: `acceptable` ("Two bounded parameters with little separation between outer and inner"). The result was better than predicted.

## Attempts
1. outer = `a`, b inner. Only two parameters, so one had to be inner. Both are bounded (0,1) with flat priors. Expected risks: a/b correlation, and a small posterior SD of logit(a) relative to nlminb's unit-scale first step. Outcome `converged`, fit time 0.436 s, 9 nlminb iterations, 15 inner solves, no failures, no warnings. distance_sd 2e-6; outer a = 2.482 (logit), SE 0.154.

## Agreement
Corrected draws (ref n=10000):
- a: ref mean 0.9233, sd 0.01095; laml mean 0.9226, sd 0.01076 (sd ratio 0.983). Mean error -0.068 ref SD, W1 0.069 (worst).
- b: ref mean 0.7856, sd 0.01910; laml mean 0.7850, sd 0.01864 (sd ratio 0.976). Mean error -0.031 SD, W1 0.044.
Location is slightly low for both (under 0.07 SD), widths about 2% narrow. Tail quantile errors for a: q05 -0.011, q50 -0.054, q95 -0.141 SD, so a slight shortfall in the upper tail; no strong skew. Uncorrected: a collapses to a point (sd 0) as expected; b has sd ratio 0.86, so ignoring outer uncertainty narrows b by about 14%.

## Findings
No package problem seen. The outer SE of logit(a) was 0.154, well below the recommended ~1, yet the fit converged with a gradient check of 2e-6 SD, so the scale risk did not bite here. No warnings.
