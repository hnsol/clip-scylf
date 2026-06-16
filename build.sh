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

echo "OK: $APP"
