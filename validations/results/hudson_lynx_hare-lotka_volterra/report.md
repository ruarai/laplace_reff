# hudson_lynx_hare-lotka_volterra

## Result
Outcome: compile_error. `validations/prepare.sh` failed, so no attempt was created (0 attempts used).
No corrected draws, no labels. Manifest prediction: class `ode`, `acceptable`, "Nonlinear ODE and zero init; AD Hessian may be unavailable".

## Attempts
None. No config was written and `run_attempt.sh` was not run.

## Agreement
Not available.

## Findings
- BridgeStan 2.9.0 `compile_model` exited with code 2 while compiling the C++ (g++ step) of `lotka_volterra.stan`. The stanc translation succeeded, with only a deprecation warning for `integrate_ode_rk45` at line 33.
- The error text was truncated by R ("BridgeStan error message too long to fully display"), so the actual g++ error was not visible. I did not rerun with `options(warning.length)` raised, as the brief says to stop. The cause is unknown. A likely area is compatibility of the deprecated `integrate_ode_rk45` with the bundled Stan Math, but that is a guess.
- This looks like an environment or model-compile problem and not a lapland problem.

## Main-session correction
The cause is now known, and the conclusions above about it are superseded. The g++ error is `coupled_ode_system.hpp:72: no matching function for call to deep_copy_vars(const std::vector<fvar<var>>&)`, the same as for `one_comp_mm_elim_abs`. Stan's ODE solvers do not support the `fvar<var>` that `BRIDGESTAN_AD_HESSIAN=true` needs, and `laml_model` requires that flag. This is a limitation of lapland on these models, not an environment problem. The model builds with the flag unset.
