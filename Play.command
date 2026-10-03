#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -x "$PROJECT_DIR/builds/StairWreck.app/Contents/MacOS/StairWreck" ]; then
  exec "$PROJECT_DIR/builds/StairWreck.app/Contents/MacOS/StairWreck"
fi
ENGINE=${GODOT_BIN:-/opt/homebrew/bin/godot}
exec "$ENGINE" --path "$PROJECT_DIR"
