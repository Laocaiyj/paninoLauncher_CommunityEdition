#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_BIN="${CORE_BIN:-$ROOT_DIR/core/dist-newstyle/build/aarch64-osx/ghc-9.6.7/panino-core-0.1.0.0/x/panino-core/build/panino-core/panino-core}"
VERSION="${VERSION:-1.20.1}"
FABRIC_VERSION="${FABRIC_VERSION:-1.20.1}"
CONCURRENCY="${CONCURRENCY:-16}"
VERIFY_ROOT="${VERIFY_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/panino-verify.XXXXXX")}"

run_step() {
  local name="$1"
  shift
  echo "==> $name"
  "$@"
}

require_core() {
  if [[ ! -x "$CORE_BIN" ]]; then
    echo "Core binary not found at $CORE_BIN"
    echo "Run ./scripts/build-core.sh first or set CORE_BIN."
    exit 1
  fi
}

vanilla_cold() {
  "$CORE_BIN" install --version "$VERSION" --game-dir "$VERIFY_ROOT/vanilla" --concurrency "$CONCURRENCY"
}

vanilla_warm() {
  "$CORE_BIN" install --version "$VERSION" --game-dir "$VERIFY_ROOT/vanilla" --concurrency "$CONCURRENCY"
}

fabric_iris_cold() {
  "$CORE_BIN" install \
    --version "$FABRIC_VERSION" \
    --game-dir "$VERIFY_ROOT/fabric-iris" \
    --concurrency "$CONCURRENCY" \
    --loader fabric \
    --shader-loader iris
}

fabric_iris_warm() {
  "$CORE_BIN" install \
    --version "$FABRIC_VERSION" \
    --game-dir "$VERIFY_ROOT/fabric-iris" \
    --concurrency "$CONCURRENCY" \
    --loader fabric \
    --shader-loader iris
}

resume_after_kill_note() {
  echo "Resume verification is covered by .part preservation and Range resume; run a cold install, kill Core mid-download, then rerun this script with VERIFY_NETWORK=1."
}

api_matrix_note() {
  if [[ -n "${PANINO_CORE_URL:-}" && -n "${PANINO_CORE_TOKEN:-}" ]]; then
    "$ROOT_DIR/scripts/benchmark-core-network.sh"
  else
    echo "Set PANINO_CORE_URL and PANINO_CORE_TOKEN to include search/project/loader API cache checks."
  fi
}

echo "verification root: $VERIFY_ROOT"
run_step "core unit/regression tests" "$ROOT_DIR/scripts/test-core.sh"
run_step "core build" "$ROOT_DIR/scripts/build-core.sh"
require_core

if [[ "${VERIFY_NETWORK:-0}" == "1" ]]; then
  run_step "cold vanilla install" vanilla_cold
  run_step "warm vanilla install" vanilla_warm
  run_step "cold Fabric + Iris install" fabric_iris_cold
  run_step "warm Fabric + Iris install" fabric_iris_warm
  run_step "API/cache benchmark matrix" api_matrix_note
  run_step "resume after kill guidance" resume_after_kill_note
else
  echo "Skipping network-heavy install matrix. Set VERIFY_NETWORK=1 to run cold/warm vanilla and Fabric+Iris installs."
fi
