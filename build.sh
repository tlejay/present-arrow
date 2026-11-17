#!/bin/bash
# Build "Present Arrow.app" into ./build and (optionally) install to /Applications.
# Usage: ./build.sh           -> build only (this Mac's architecture)
#        ./build.sh install   -> build, copy to /Applications, launch
#        ./build.sh zip       -> universal (Apple Silicon + Intel) build, zipped for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Present Arrow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BIN="$APP/Contents/MacOS/PresentArrow"
compile() { swiftc -O -swift-version 5 -target "$1-apple-macos13.0" \
  -framework AppKit -framework ServiceManagement Sources/main.swift -o "$2"; }
if [[ "${1:-}" == "zip" ]]; then
  compile arm64 build/PresentArrow-arm64
  compile x86_64 build/PresentArrow-x86_64
  lipo -create build/PresentArrow-arm64 build/PresentArrow-x86_64 -output "$BIN"
else
  compile "$(uname -m)" "$BIN"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Present Arrow</string>
  <key>CFBundleDisplayName</key><string>Present Arrow</string>
  <key>CFBundleIdentifier</key><string>com.madebytle.presentarrow</string>
  <key>CFBundleExecutable</key><string>PresentArrow</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built: $APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x PresentArrow 2>/dev/null && sleep 1 || true
  rm -rf "/Applications/Present Arrow.app"
  cp -R "$APP" /Applications/
  open "/Applications/Present Arrow.app"
  echo "Installed to /Applications and launched"
fi

if [[ "${1:-}" == "zip" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP" "build/Present-Arrow.zip"
  echo "Zipped: build/Present-Arrow.zip"
fi
