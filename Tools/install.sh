#!/bin/zsh
# Builds Notch in Release and installs it to /Applications, replacing any existing copy, then launches it.
#
# Usage (from anywhere):  Tools/install.sh
#
# Quit or stop any copy you're running from Xcode first if you want to keep it open; this script quits
# every running Notch so files are never replaced under a running app.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DESTINATION="/Applications/Notch.app"

# Every build gets a unique, increasing build number: the number of commits so far.
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"

echo "→ Building Release (build $BUILD_NUMBER)…"
xcodebuild build \
    -project "$ROOT/Notch.xcodeproj" \
    -scheme Notch \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    -quiet

APP="$BUILD_DIR/Build/Products/Release/Notch.app"
codesign --verify --deep --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "→ Built Notch $VERSION ($BUILD_NUMBER), signature verified"

if pgrep -x Notch > /dev/null; then
    echo "→ Quitting the running Notch…"
    pkill -x Notch || true
    for _ in {1..50}; do
        pgrep -x Notch > /dev/null || break
        sleep 0.1
    done
fi

echo "→ Installing to $DESTINATION"
rm -rf "$DESTINATION"
ditto "$APP" "$DESTINATION"

open "$DESTINATION"
echo "✓ Installed and launched Notch $VERSION ($BUILD_NUMBER)"
