#!/usr/bin/env bash
# Packages Downbar.app into a distributable, *styled* .dmg: a Finder window with
# a custom background (app icon > Applications chevron), 128px icons positioned
# side-by-side, and an /Applications drop link — the familiar "drag to install"
# look. The background PNG is rendered by a throwaway Swift program (same
# technique as make-icon.sh), Finder is scripted via osascript to lay out the
# window, then the read-write image is converted to compressed UDZO.
#
# NOTE: this wraps whatever signature Downbar.app already has. The default
# build-app.sh produces an *ad-hoc* signature, so the resulting DMG is NOT
# notarized — recipients will see a Gatekeeper warning and must bypass it. For a
# clean install, sign with a Developer ID and notarize first (see RELEASE.md).
#
# Requires a GUI session (osascript drives Finder). First run may trigger a
# one-time "allow Terminal to control Finder" automation prompt.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="Downbar.app"
VOL="Downbar"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 1.0.0)"
DMG="Downbar-${VERSION}.dmg"

# Window geometry (Finder points). Icons sit on a shared row; the background
# chevron is drawn to land exactly between them.
WIN_W=660; WIN_H=400
ICON_SIZE=128
APP_X=165; APPS_X=495; ROW_Y=175

if [[ ! -d "$APP" ]]; then
  echo "==> $APP not found; building it"
  ./scripts/build-app.sh
fi

STAGE="$(mktemp -d)"
GEN_SRC="$(mktemp -t downbar-dmg-bg-XXXXXX).swift"
RW_DMG="$(mktemp -t downbar-rw-XXXXXX).dmg"
MOUNT=""
# Detach on exit too, so a failed run doesn't strand a mounted volume that
# steals the "Downbar" name from the next run.
trap '[[ -n "$MOUNT" ]] && hdiutil detach "$MOUNT" -force -quiet 2>/dev/null; rm -rf "$STAGE" "$GEN_SRC" "$RW_DMG"' EXIT

# ---------------------------------------------------------------- background
# Rendered @2x (1320x800) with 144dpi metadata so Finder shows it at 660x400pt.
# Light neutral canvas + a dark ">" chevron centered between the two icons.
cat > "$GEN_SRC" <<SWIFT
import AppKit
import CoreGraphics
import Foundation

let scale: CGFloat = 2
let w: CGFloat = ${WIN_W} * scale
let h: CGFloat = ${WIN_H} * scale
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(w), height: Int(h),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("could not create CGContext") }

// Canvas: the light gray Finder-window tone the classic drag-to-install DMGs use.
ctx.setFillColor(CGColor(red: 0.941, green: 0.941, blue: 0.949, alpha: 1.0))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

// ">" chevron centered between the app icon and the Applications alias.
// Icon centers sit at y=${ROW_Y}pt from the top; CG is y-up, so flip.
let cx = w / 2
let cy = h - ${ROW_Y} * scale
let arm: CGFloat = 34 * scale      // chevron arm length
let thick: CGFloat = 13 * scale    // stroke width

ctx.setStrokeColor(CGColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0))
ctx.setLineWidth(thick)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.beginPath()
ctx.move(to: CGPoint(x: cx - arm * 0.45, y: cy + arm))
ctx.addLine(to: CGPoint(x: cx + arm * 0.55, y: cy))
ctx.addLine(to: CGPoint(x: cx - arm * 0.45, y: cy - arm))
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

echo "==> Rendering DMG background"
mkdir -p "$STAGE/.background"
swift "$GEN_SRC" "$STAGE/.background/background.png"
# 144dpi metadata makes Finder treat the @2x pixels as ${WIN_W}x${WIN_H} points.
sips -s dpiWidth 144 -s dpiHeight 144 "$STAGE/.background/background.png" >/dev/null

# ------------------------------------------------------------------- staging
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
fi

# ------------------------------------------------- read-write image + layout
echo "==> Creating read-write image"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW \
  -fs APFS "$RW_DMG" >/dev/null

# A stale mount from an earlier failed run would grab the "$VOL" name and make
# the new volume mount as "$VOL 1"; clear it first.
[[ -d "/Volumes/$VOL" ]] && hdiutil detach "/Volumes/$VOL" -force -quiet || true

# Take the real mount point from hdiutil rather than assuming /Volumes/$VOL —
# that's also the disk name Finder will see.
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" \
  | grep -o '/Volumes/.*' | tail -1)"
VOL_NAME="$(basename "$MOUNT")"

# Flag the custom volume icon (best-effort; needs Xcode's SetFile).
if [[ -f "$MOUNT/.VolumeIcon.icns" ]] && command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT" || true
fi

# Finder registers a freshly mounted disk asynchronously; scripting it too
# early fails with -1728 "Can't get disk". Wait until it's visible.
for _ in $(seq 1 20); do
  if osascript -e "tell application \"Finder\" to get disk \"$VOL_NAME\"" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

echo "==> Laying out Finder window"
osascript <<OSA
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $((200 + WIN_W)), $((120 + WIN_H + 28))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP" of container window to {$APP_X, $ROW_Y}
    set position of item "Applications" of container window to {$APPS_X, $ROW_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

sync
hdiutil detach "$MOUNT" >/dev/null
MOUNT=""

# ------------------------------------------------------------------ compress
echo "==> Converting to compressed $DMG"
rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
