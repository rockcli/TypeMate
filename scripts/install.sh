#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

echo "==> Installing to /Applications/TypeMate.app"
pkill -x TypeMate 2>/dev/null || true
rm -rf /Applications/TypeMate.app
cp -R build/TypeMate.app /Applications/TypeMate.app

echo ""
echo "Installed /Applications/TypeMate.app"
echo "Launch directly (recommended for ad-hoc signed CGEvent apps):"
echo "  /Applications/TypeMate.app/Contents/MacOS/TypeMate &"
echo ""
echo "If macOS prompts for Input Monitoring / Accessibility, grant permission to"
echo "/Applications/TypeMate.app in System Settings -> Privacy & Security and restart."
