#!/usr/bin/env bash
# Packages Downbar.app into a distributable .dmg (with an /Applications drop link).
# NOTE: this wraps whatever signature Downbar.app already has. The default
# build-app.sh produces an *ad-hoc* signature, so the resulting DMG is NOT
# notarized — recipients will see a Gatekeeper warning and must bypass it. For a
# clean install, sign with a Developer ID and notarize first (see RELEASE.md).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="Downbar.app"
VOL="Downbar"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 1.0.0)"
DMG="Downbar-${VERSION}.dmg"

if [[ ! -d "$APP" ]]; then
  echo "==> $APP not found; building it"
  ./scripts/build-app.sh
fi

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG"
rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
