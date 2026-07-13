#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/Applications/CommandBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
PLIST_SOURCE="$ROOT_DIR/CommandBar.plist"

echo "Building CommandBar..."
xcrun swift build --package-path "$ROOT_DIR"

BIN_DIR="$(xcrun swift build --package-path "$ROOT_DIR" --show-bin-path)"
BIN_PATH="$BIN_DIR/CommandBar"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "Missing built binary at $BIN_PATH" >&2
    exit 1
fi

if [[ ! -f "$PLIST_SOURCE" ]]; then
    echo "Missing plist at $PLIST_SOURCE" >&2
    exit 1
fi

echo "Installing app bundle to $APP_DIR..."
mkdir -p "$MACOS_DIR"

pkill -f "CommandBar.app/Contents/MacOS/CommandBar" 2>/dev/null || true

cp "$BIN_PATH" "$MACOS_DIR/CommandBar"
chmod +x "$MACOS_DIR/CommandBar"
cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"

touch "$APP_DIR"

echo "Launching CommandBar..."
open "$APP_DIR"

echo "CommandBar is installed in ~/Applications/CommandBar.app"
