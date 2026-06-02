#!/usr/bin/env bash
# Builds Downbar.app — a proper LSUIElement .app bundle around the SPM binary.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Downbar"
BUNDLE_ID="com.nathantarasiuk.downbar"
APP_DIR="${APP_NAME}.app"

echo "==> swift build -c release"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "==> Assembling ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
else
  echo "warning: Resources/AppIcon.icns missing — run scripts/make-icon.sh" >&2
fi

echo "==> Ad-hoc codesign (sandboxed, hardened runtime)"
codesign --force --deep \
  --options runtime \
  --entitlements Resources/Downbar.entitlements \
  --sign - "$APP_DIR"

echo "==> Done: ${APP_DIR}"
echo "Run it with:  open ${APP_DIR}"
