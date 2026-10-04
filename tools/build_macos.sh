#!/bin/sh
# Uses the locally installed official Godot executable as the runtime.
# A PCK beside the renamed binary makes this a self-contained game app.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENGINE=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
APP_DIR="$PROJECT_DIR/builds/StairWreck.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
"$ENGINE" --headless --path "$PROJECT_DIR" --import --log-file "$PROJECT_DIR/builds/build_import.log" > "$PROJECT_DIR/builds/build_import_output.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error' "$PROJECT_DIR/builds/build_import_output.log"; then cat "$PROJECT_DIR/builds/build_import_output.log"; exit 1; fi
"$ENGINE" --headless --path "$PROJECT_DIR" --export-pack macOS "$APP_DIR/Contents/MacOS/StairWreck.pck" --log-file "$PROJECT_DIR/builds/export.log" > "$PROJECT_DIR/builds/export_output.log" 2>&1
if rg -q 'SCRIPT ERROR|Failed to export|ERROR.*[Ee]xport' "$PROJECT_DIR/builds/export_output.log"; then cat "$PROJECT_DIR/builds/export_output.log"; exit 1; fi
cp "$ENGINE" "$APP_DIR/Contents/MacOS/StairWreck"
chmod +x "$APP_DIR/Contents/MacOS/StairWreck"
cp "$PROJECT_DIR/docs/GODOT_LICENSE.txt" "$APP_DIR/Contents/Resources/GODOT_LICENSE.txt"
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/GAME_LICENSE.txt"
cp "$PROJECT_DIR/assets/StairWreck.icns" "$APP_DIR/Contents/Resources/StairWreck.icns"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>StairWreck</string>
<key>CFBundleIdentifier</key><string>com.stairwreck.game</string>
<key>CFBundleName</key><string>STAIR WRECK</string>
<key>CFBundleDisplayName</key><string>STAIR WRECK</string>
<key>CFBundlePackageType</key><string>APPL</string>
<!-- Version 3 adds physical traffic, one crashbreaker, a skinned rider and redesigned HUD. -->
<key>CFBundleShortVersionString</key><string>3.0</string>
<key>CFBundleVersion</key><string>3.0</string>
<key>CFBundleIconFile</key><string>StairWreck.icns</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSRequiresAquaSystemAppearance</key><false/>
<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
</dict></plist>
PLIST
# Refresh the local ad-hoc signature after bundling; no certificate or account required.
codesign --force --deep --sign - "$APP_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$PROJECT_DIR/builds/StairWreck-macOS.zip"
printf '%s\n' "Built: $APP_DIR" "Archive: $PROJECT_DIR/builds/StairWreck-macOS.zip"
