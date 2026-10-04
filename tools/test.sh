#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENGINE=${GODOT_BIN:-godot}
mkdir -p "$PROJECT_DIR/builds"
"$ENGINE" --headless --path "$PROJECT_DIR" --import --log-file "$PROJECT_DIR/builds/test_import.log" > "$PROJECT_DIR/builds/test_import_output.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error' "$PROJECT_DIR/builds/test_import_output.log"; then
  cat "$PROJECT_DIR/builds/test_import_output.log"
  exit 1
fi
for suite in test_rules test_injuries test_inputs test_game test_routes test_playability test_ui test_audio; do
  "$ENGINE" --headless --path "$PROJECT_DIR" --fixed-fps 60 --script "tests/$suite.gd" --log-file "$PROJECT_DIR/builds/$suite.log" -- --test-mode > "$PROJECT_DIR/builds/$suite.output.log" 2>&1
  cat "$PROJECT_DIR/builds/$suite.output.log"
  if rg -q 'SCRIPT ERROR|FAIL:|leaked at exit|resources still in use' "$PROJECT_DIR/builds/$suite.output.log"; then exit 1; fi
done
