#!/bin/sh
# Downbar installer — https://downbar.app
#
# Usage:  curl -fsSL https://downbar.app/install | sh
#
# Downloads the latest DMG (/dl/latest always points at the current release)
# and installs Downbar.app into /Applications — or ~/Applications when
# /Applications isn't writable, or $DOWNBAR_INSTALL_DIR if set.
set -eu

say()  { printf '%s\n' "$*"; }
fail() { printf 'downbar: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "Downbar is a macOS app."
[ "$(uname -m)" = arm64 ]  || fail "Downbar needs Apple silicon (arm64)."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$macos_major" -ge 14 ] || \
  fail "Downbar needs macOS 14 or later (this Mac runs $(sw_vers -productVersion))."

tmp="$(mktemp -d)"
mount=""
cleanup() {
  [ -n "$mount" ] && hdiutil detach "$mount" -quiet 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

say "Downloading Downbar..."
curl -fsSL -o "$tmp/Downbar.dmg" "https://downbar.app/dl/latest"

mount="$(hdiutil attach -nobrowse -readonly -noautoopen "$tmp/Downbar.dmg" \
  | grep -o '/Volumes/.*' | tail -1)"
[ -d "$mount/Downbar.app" ] || fail "unexpected DMG contents; aborting."

if [ -n "${DOWNBAR_INSTALL_DIR:-}" ]; then
  dest_dir="$DOWNBAR_INSTALL_DIR"
  mkdir -p "$dest_dir"
elif [ -w /Applications ]; then
  dest_dir="/Applications"
else
  dest_dir="$HOME/Applications"
  mkdir -p "$dest_dir"
fi
dest="$dest_dir/Downbar.app"

# Replace an existing copy cleanly: quit it first, then swap.
if [ -d "$dest" ]; then
  osascript -e 'tell application "Downbar" to quit' >/dev/null 2>&1 || true
  rm -rf "$dest"
fi
ditto "$mount/Downbar.app" "$dest"

version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' \
  "$dest/Contents/Info.plist" 2>/dev/null || echo unknown)"
say "Installed Downbar $version to $dest_dir."
say "Start it with:  open -a Downbar"
