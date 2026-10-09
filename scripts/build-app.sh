#!/bin/bash
# Builds "build/Sensible Defaults.app" (ad-hoc signed).
#   scripts/build-app.sh             build for this Mac
#   scripts/build-app.sh --universal build arm64 + x86_64
#   scripts/build-app.sh --install   also copy to ~/Applications and register the file type claims
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Sensible Defaults.app"
ARCHS=()
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --universal) ARCHS=(--arch arm64 --arch x86_64) ;;
    --install) INSTALL=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/SensibleDefaults"

if [ ! -f Support/AppIcon.icns ]; then
  swift scripts/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o Support/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SensibleDefaults"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns Support/editors.json "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$INSTALL" = 1 ]; then
  DEST="$HOME/Applications/Sensible Defaults.app"
  LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  mkdir -p "$HOME/Applications"
  pkill -x SensibleDefaults 2>/dev/null || true
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  "$LSREGISTER" -f "$DEST"
  # Launch Services ignores the claims of an app that has never been launched.
  open -g "$DEST" --args --register
  echo "Installed $DEST"
fi
