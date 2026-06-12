#!/bin/zsh
set -e
cd "$(dirname "$0")"

swift build -c release

APP=build/QuickDrop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
cp .build/release/QuickDrop "$APP/Contents/MacOS/"

echo "OK: $APP"
