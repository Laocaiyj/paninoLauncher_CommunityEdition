#!/bin/sh
set -eu

cd "$(dirname "$0")/../core"

log_file="${TMPDIR:-/tmp}/panino-build-core-$$.log"
trap 'rm -f "$log_file"' EXIT

if cabal build all >"$log_file" 2>&1; then
  cat "$log_file"
else
  status=$?
  cat "$log_file"
  exit "$status"
fi

if grep -E '^[^:]+:[0-9]+:[0-9]+: warning:' "$log_file" >/dev/null; then
  echo "Core build emitted GHC warnings; warnings are treated as failures." >&2
  grep -E '^[^:]+:[0-9]+:[0-9]+: warning:' "$log_file" >&2
  exit 1
fi
