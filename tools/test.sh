#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENGINE=${GODOT_BIN:-godot}
exec python3 "$PROJECT_DIR/tools/run_bounded.py" suite --project-dir "$PROJECT_DIR" --engine "$ENGINE" "$@"
