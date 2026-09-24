#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuickNotepad"
APP_BUNDLE="$REPO_ROOT/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

cd "$REPO_ROOT"
swift build -c release --toolset Toolset.json

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"

cp ".build/release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.priyam.quicknotepad</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Quick Notepad saves your captures into Apple Notes.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier com.priyam.quicknotepad "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
