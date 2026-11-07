#!/usr/bin/env bash
# Install lapland from a fixed commit, so validation is unaffected by the working tree.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sha="$(git -C "$here" rev-parse "${1:-754026a}")"
rm -rf "$here/build/src" "$here/build/lib"
mkdir -p "$here/build/src" "$here/build/lib"
git -C "$here/.." archive "$sha" DESCRIPTION NAMESPACE LICENSE R man | tar -x -C "$here/build/src"
R CMD INSTALL --no-docs --library="$here/build/lib" "$here/build/src"
echo "$sha" > "$here/build/package_sha"
echo "Installed lapland at $sha"
