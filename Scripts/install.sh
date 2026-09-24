#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuickNotepad"
DEST_APPS="$HOME/Applications"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.priyam.quicknotepad.plist"

mkdir -p "$DEST_APPS" "$LAUNCH_AGENTS"

rm -rf "$DEST_APPS/$APP_NAME.app"
cp -R "$REPO_ROOT/$APP_NAME.app" "$DEST_APPS/$APP_NAME.app"

cp "$REPO_ROOT/LaunchAgent/$PLIST_NAME" "$LAUNCH_AGENTS/$PLIST_NAME"

launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"

echo "Installed to $DEST_APPS/$APP_NAME.app and loaded LaunchAgent."
