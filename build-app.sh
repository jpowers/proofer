#!/bin/bash
# Builds Proofer.app into ./build. Pass --install to also copy it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Proofer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Proofer "$APP/Contents/MacOS/Proofer"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"  # regenerate with: swift scripts/make-icon.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Proofer</string>
    <key>CFBundleDisplayName</key><string>Proofer</string>
    <key>CFBundleIdentifier</key><string>com.vermonster.proofer</string>
    <key>CFBundleExecutable</key><string>Proofer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally built apps on Apple Silicon. Gatekeeper doesn't block
# apps you build yourself, so no Developer ID is needed.
codesign --force --sign - "$APP"
echo "Built $APP"

# ./build-app.sh --install also copies the app into /Applications (quitting any running copy first).
if [[ "${1:-}" == "--install" ]]; then
    pkill -x Proofer 2>/dev/null || true
    rm -rf /Applications/Proofer.app
    cp -R "$APP" /Applications/Proofer.app
    echo "Installed /Applications/Proofer.app"
    open /Applications/Proofer.app
fi
