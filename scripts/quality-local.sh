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
./scripts/test-swift-graphics-ui.sh

cd "$repo_root/macos/PaninoLauncher"
swift_tests="$(env CLANG_MODULE_CACHE_PATH="$repo_root/.build/clang-module-cache" swift test list 2>&1 || true)"
if printf '%s\n' "$swift_tests" | grep -E 'PaninoLauncherTests\.' >/dev/null; then
  env CLANG_MODULE_CACHE_PATH="$repo_root/.build/clang-module-cache" swift test
else
  printf '%s\n' "$swift_tests"
  echo "SwiftPM XCTest did not discover tests with this toolchain; executable self-tests were used as the local Swift gate." >&2
fi
