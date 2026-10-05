#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENGINE=${GODOT_BIN:-/opt/homebrew/bin/godot}
# This workspace launcher runs its current source. The standalone app is launched
# directly from its verified candidate directory; an old bundle cannot mask edits.
exec "$ENGINE" --path "$PROJECT_DIR" "$@"
