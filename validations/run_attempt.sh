#!/usr/bin/env bash
# Run one attempt: run_attempt.sh <posterior> <attempt>
# Needs results/<posterior>/attempt-<n>/config.json. A finished attempt cannot be rerun.
# Time limits: 600s for laml_fit, 1800s for draws. Compilation is outside both.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
results="${VALIDATION_RESULTS:-$here/results}"
export VALIDATION_RESULTS="$results"
p="$1"; n="$2"
dir="$results/$p/attempt-$n"
scripts="$here/scripts"

fail() { echo "REFUSED: $*" >&2; exit 2; }
grep -q "^$p," "$here/manifest.csv" || fail "$p is not in the manifest"
[[ "$n" =~ ^[123]$ ]] || fail "attempt must be 1, 2 or 3"
[ -f "$dir/config.json" ] || fail "missing $dir/config.json"
[ ! -f "$dir/status.json" ] || fail "attempt $n has already run"
for ((i = 1; i < n; i++)); do
  prev="$results/$p/attempt-$i/status.json"
  [ -f "$prev" ] || fail "attempt $i has not run"
  # A converged fit is final, however well it agrees with the reference.
  if grep -q '"outcome": "converged"' "$prev"; then fail "attempt $i converged, so no retry is allowed"; fi
done

timeout 1800 Rscript "$scripts/compile.R" "$p" "$n" > "$dir/compile.log" 2>&1
compile_rc=$?
if [ "$compile_rc" -eq 3 ]; then
  cat "$dir/compile.log" >&2
  rm -f "$dir/compile.log"
  fail "invalid config; this attempt was not consumed"
fi

fit_rc=-1; draws_rc=-1
if [ "$compile_rc" -eq 0 ]; then
  timeout -k 5 "${VALIDATION_FIT_LIMIT:-600}" Rscript "$scripts/fit.R" "$p" "$n" > "$dir/fit.log" 2>&1
  fit_rc=$?
  if [ "$fit_rc" -eq 0 ] && grep -q '"converged": true' "$dir/fit_summary.json"; then
    timeout -k 5 1800 Rscript "$scripts/draws.R" "$p" "$n" > "$dir/draws.log" 2>&1
    draws_rc=$?
    Rscript "$scripts/compare.R" "$p" "$n" > "$dir/compare.log" 2>&1
  fi
fi
Rscript "$scripts/finalise.R" "$p" "$n" "$compile_rc" "$fit_rc" "$draws_rc"
