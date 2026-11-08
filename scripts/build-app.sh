#!/bin/bash
# Builds "Notch Dino.app" into .build/app: a release build, an Info.plist and an ad-hoc signature.
# Racing needs the app: macOS shows the Local Network prompt only for an app bundle. `swift run` still works for solo.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.2.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP=".build/app/Notch Dino.app"

swift build -c release --product NotchDino
BIN="$(swift build -c release --show-bin-path)/NotchDino"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchDino"
cp scripts/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.neelrocketbots.notchdino</string>
  <key>CFBundleName</key><string>Notch Dino</string>
  <key>CFBundleDisplayName</key><string>Notch Dino</string>
  <key>CFBundleExecutable</key><string>NotchDino</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>Notch Dino looks for other Macs on your local network so you can race them. It only listens while a race is open.</string>
  <key>NSBonjourServices</key><array><string>_notchdino._tcp</string></array>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - "$APP"
echo "$APP"
