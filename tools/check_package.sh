#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNTIME="$PROJECT_DIR/builds/StairWreck.app/Contents/MacOS/StairWreck"
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/stairwreck-package.XXXXXX")
trap 'rmdir "$CHECK_DIR" 2>/dev/null || true' EXIT
for level in 0 1 2; do
  "$RUNTIME" --headless --path "$CHECK_DIR" --fixed-fps 60 --log-file "$PROJECT_DIR/builds/package_level_$level.log" -- --self-check "--level=$level" > "$PROJECT_DIR/builds/package_level_$level.output.log" 2>&1
  cat "$PROJECT_DIR/builds/package_level_$level.output.log"
  if ! rg -q 'SELF_CHECK:' "$PROJECT_DIR/builds/package_level_$level.output.log"; then exit 1; fi
  if rg -q 'SCRIPT ERROR|leaked at exit|resources still in use' "$PROJECT_DIR/builds/package_level_$level.output.log"; then exit 1; fi
done
"$RUNTIME" --headless --path "$CHECK_DIR" --script "$PROJECT_DIR/tools/package_assets_probe.gd" --log-file "$PROJECT_DIR/builds/package_assets.log" > "$PROJECT_DIR/builds/package_assets.output.log" 2>&1
cat "$PROJECT_DIR/builds/package_assets.output.log"
if ! rg -q 'PACKAGED_ASSETS: 19 models / 15 audio; 0 failures' "$PROJECT_DIR/builds/package_assets.output.log"; then exit 1; fi
if rg -q 'SCRIPT ERROR|leaked at exit|resources still in use' "$PROJECT_DIR/builds/package_assets.output.log"; then exit 1; fi
codesign --verify --deep --strict "$PROJECT_DIR/builds/StairWreck.app"
printf '%s\n' 'Packaged game: three levels complete; app signature valid.'
