#!/bin/sh
set -eu

cd "$(dirname "$0")/../macos/PaninoLauncher"
swift build
