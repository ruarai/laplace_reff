#!/usr/bin/env bash
# Compile a posterior's model and list its unconstrained parameters. No fitting.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec Rscript "$here/scripts/compile.R" "$1"
