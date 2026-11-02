#!/bin/zsh
set -e
cd "$(dirname "$0")"

swift build -c release

APP=build/ClipScylf.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/"
cp .build/release/ClipScylf "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# macOS 27.2+ drops file drags unless the app itself can read the file,
# so ClipScylf needs Full Disk Access. Sign with a stable identity so the
# grant survives rebuilds. Override with CODESIGN_IDENTITY; ad-hoc fallback.
IDENTITY=${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | awk -F'"' '/Apple Development/ { print $2; exit }')}
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Signed: ${IDENTITY:-ad-hoc}"

echo "OK: $APP"
