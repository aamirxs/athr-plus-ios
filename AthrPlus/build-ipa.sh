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

echo "3. Creating AthrPlus.ipa..."
zip -qr AthrPlus.ipa Payload

rm -rf Payload

echo "========================================="
echo " SUCCESS! Built: AthrPlus.ipa            "
echo " Size: $(du -sh AthrPlus.ipa | cut -f1)  "
echo " Ready for TrollStore / AltStore / Sideloadly"
echo "========================================="
