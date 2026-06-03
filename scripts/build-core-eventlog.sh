#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
cabal build exe:panino-core --project-file=cabal.project.eventlog
