#!/bin/zsh
# Builds rezfish.app into ./dist using only the Swift command line tools (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release 2>&1 | tail -1

APP=dist/rezfish.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/rezfish "$APP/Contents/MacOS/rezfish"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

# ./build.sh install  → copy to /Applications and relaunch
if [[ "${1:-}" == "install" ]]; then
  pkill -x rezfish || true
  rm -rf /Applications/rezfish.app
  cp -R "$APP" /Applications/
  open /Applications/rezfish.app
  echo "Installed to /Applications/rezfish.app"
fi
