#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building TypeMate (release)"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="build/TypeMate.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/TypeMate" "$APP_DIR/Contents/MacOS/TypeMate"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "==> Ad-hoc signing $APP_DIR"
codesign --force --deep -s - "$APP_DIR"
echo "Built $APP_DIR"
