#!/usr/bin/env bash
# Wait up to 9 minutes for an attempt to finish. Prints RUNNING, the status file, or a refusal.
here="$(cd "$(dirname "$0")" && pwd)"
results="${VALIDATION_RESULTS:-$here/results}"
dir="$results/$1/attempt-$2"
for _ in $(seq 1 108); do
  if [ -f "$dir/status.json" ]; then cat "$dir/status.json"; exit 0; fi
  if grep -q REFUSED "$dir/run.log" 2>/dev/null; then cat "$dir/run.log"; exit 1; fi
  sleep 5
done
echo RUNNING
