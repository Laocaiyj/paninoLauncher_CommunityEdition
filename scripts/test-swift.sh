#!/bin/sh
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$repo_root/.build/clang-module-cache}"

cd "$repo_root/macos/PaninoLauncher"
swift run PaninoLauncher --self-test-logic
