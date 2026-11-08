#!/bin/bash
# Regenerates scripts/icon/AppIcon.icns from scripts/icon/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/icon"
rm -rf AppIcon.iconset
swift make-icon.swift pip.png AppIcon.iconset
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset
echo "scripts/icon/AppIcon.icns"
