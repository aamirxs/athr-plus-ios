#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " Building Athr+ iOS (.ipa package)       "
echo "========================================="

# Clean build artifacts
rm -rf build Payload AthrPlus.ipa
mkdir -p build Payload

echo "1. Archiving AthrPlus Release build..."
xcodebuild archive \
  -project AthrPlus.xcodeproj \
  -scheme AthrPlus \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "build/AthrPlus.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS=""

echo "2. Packaging .app into Payload structure..."
cp -r build/AthrPlus.xcarchive/Products/Applications/*.app Payload/

# Inspect and ensure main app Info.plist has UILaunchScreen (fixes letterboxing/black bars)
for app in Payload/*.app; do
  if [ -d "$app" ]; then
    echo "=== Checking Info.plist for main app: $app ==="
    if ! plutil -extract UILaunchScreen xml1 -o - "$app/Info.plist" > /dev/null 2>&1; then
      echo "UILaunchScreen missing! Injecting into $app/Info.plist to enable full screen on modern iPhones..."
      plutil -insert UILaunchScreen -xml "<dict/>" "$app/Info.plist"
    else
      echo "OK: UILaunchScreen is present in $app/Info.plist"
    fi
    if ! plutil -extract NSLocationWhenInUseUsageDescription xml1 -o - "$app/Info.plist" > /dev/null 2>&1; then
      plutil -insert NSLocationWhenInUseUsageDescription -string "Athr+ requires access to your location to display your position on the map relative to your scooter." "$app/Info.plist"
    fi
    if ! plutil -extract NSLocationAlwaysAndWhenInUseUsageDescription xml1 -o - "$app/Info.plist" > /dev/null 2>&1; then
      plutil -insert NSLocationAlwaysAndWhenInUseUsageDescription -string "Athr+ uses location services to keep you updated on your scooter proximity." "$app/Info.plist"
    fi
    echo "=== Verified $app/Info.plist content: ==="
    plutil -p "$app/Info.plist"
  fi
done

# Inspect and ensure every .appex has a valid NSExtension dictionary in Info.plist
for appex in Payload/*.app/PlugIns/*.appex; do
  if [ -d "$appex" ]; then
    echo "=== Checking Info.plist for app extension: $appex ==="
    plutil -p "$appex/Info.plist" || true
    if ! plutil -extract NSExtension xml1 -o - "$appex/Info.plist" > /dev/null 2>&1; then
      echo "WARNING: NSExtension missing! Injecting into $appex/Info.plist..."
      plutil -insert NSExtension -xml "<dict><key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string></dict>" "$appex/Info.plist"
    else
      echo "OK: NSExtension dictionary is present in $appex/Info.plist"
    fi
    echo "=== Verified $appex/Info.plist content: ==="
    plutil -p "$appex/Info.plist"
  fi
done

echo "3. Creating AthrPlus.ipa..."
zip -qr AthrPlus.ipa Payload

rm -rf Payload

echo "========================================="
echo " SUCCESS! Built: AthrPlus.ipa            "
echo " Size: $(du -sh AthrPlus.ipa | cut -f1)  "
echo " Ready for TrollStore / AltStore / Sideloadly"
echo "========================================="
