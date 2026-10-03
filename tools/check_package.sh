#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNTIME="$PROJECT_DIR/builds/StairWreck.app/Contents/MacOS/StairWreck"
for level in 0 1 2; do
  "$RUNTIME" --headless --fixed-fps 60 --log-file "$PROJECT_DIR/builds/package_level_$level.log" -- --self-check "--level=$level" > "$PROJECT_DIR/builds/package_level_$level.output.log" 2>&1
  cat "$PROJECT_DIR/builds/package_level_$level.output.log"
  if ! rg -q 'SELF_CHECK:' "$PROJECT_DIR/builds/package_level_$level.output.log"; then exit 1; fi
  if rg -q 'SCRIPT ERROR|leaked at exit|resources still in use' "$PROJECT_DIR/builds/package_level_$level.output.log"; then exit 1; fi
done
codesign --verify --deep --strict "$PROJECT_DIR/builds/StairWreck.app"
printf '%s\n' 'Packaged game: three levels complete; app signature valid.'
