#!/bin/sh
set -eu

cd "$(dirname "$0")/../core"
cabal build all
