#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR/core"
cabal run panino-core -- --version
cabal run panino-core -- health

"$ROOT_DIR/macos/PaninoLauncher/Support/TestBinary/panino-test-core"
