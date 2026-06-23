#!/bin/sh
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

git diff --check

if rg -n 'error "|undefined|TODO|fatal' core/src macos/PaninoLauncher/PaninoLauncher; then
  echo "Unsafe failure token scan failed." >&2
  exit 1
fi

./scripts/check-core-swift-contracts.sh
./scripts/test-core.sh
./scripts/build-core.sh
./scripts/build-swift.sh

cd "$repo_root/macos/PaninoLauncher"
env CLANG_MODULE_CACHE_PATH="$repo_root/.build/clang-module-cache" swift test
env CLANG_MODULE_CACHE_PATH="$repo_root/.build/clang-module-cache" swift run PaninoLauncher --self-test-core-env
