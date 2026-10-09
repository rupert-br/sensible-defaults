#!/bin/bash
# Builds a universal, Developer ID signed and notarized zip for a GitHub release.
# One-time setup (run yourself, it asks for an app-specific password):
#   xcrun notarytool store-credentials sensible-defaults --apple-id <you> --team-id <team>
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-sensible-defaults}"
APP="build/Sensible Defaults.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
ZIP="build/SensibleDefaults-$VERSION.zip"

scripts/build-app.sh --universal
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl -a -vv "$APP"

echo "Release archive: $ZIP"
echo "sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
