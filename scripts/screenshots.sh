#!/usr/bin/env bash
# Captures App Store screenshots of Downbar's panel and Settings in light and
# dark mode, using macOS `screencapture`. Output lands in docs/screenshots/.
#
# Mac App Store screenshot requirements (as of 2026):
#   • Accepted display sizes (pixels): 1280x800, 1440x900, 2560x1600, 2880x1800.
#   • PNG (or JPEG), RGB, no alpha; up to 10 screenshots.
#   • 2880x1800 (16:10 Retina) is the recommended capture size — looks crisp on
#     the listing and downscales cleanly to the others.
#
# This is a window-capture helper, not a pixel-perfect generator: you arrange the
# panel / Settings on screen, then this script captures the focused window and
# (optionally) pads it onto a clean App-Store-sized canvas with `sips`.
#
# Usage:
#   scripts/screenshots.sh                 # interactive: prompts before each shot
#   scripts/screenshots.sh panel-light     # capture a single named shot now
#
# Workflow for a full set:
#   1. Switch to Light mode (System Settings → Appearance, or `defaults`).
#   2. Run the script; for each prompt, click the Downbar menu-bar icon to open
#      the panel (or open Settings), then press Return to capture.
#   3. Repeat in Dark mode.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="docs/screenshots"
mkdir -p "$OUT_DIR"

# Recommended App Store capture canvas (16:10 Retina).
CANVAS_W=2880
CANVAS_H=1800

# Capture the user-selected window (interactive crosshair → spacebar → window).
# -o drops the window shadow; -t png sets the format.
capture_window() {
  local name="$1"
  local path="$OUT_DIR/${name}.png"
  echo "==> ${name}: position the panel/Settings, then click the window to capture."
  screencapture -o -t png -W "$path"
  echo "    saved $path"
}

# Optional: pad a captured window onto a clean App-Store-sized canvas so every
# shot has identical dimensions. Requires the shot to be <= the canvas.
pad_to_canvas() {
  local name="$1"
  local path="$OUT_DIR/${name}.png"
  [[ -f "$path" ]] || return 0
  sips -p "$CANVAS_H" "$CANVAS_W" "$path" --out "$path" >/dev/null
  echo "    padded $path to ${CANVAS_W}x${CANVAS_H}"
}

current_appearance() {
  if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
    echo "Dark"
  else
    echo "Light"
  fi
}

shoot() {
  local name="$1"
  capture_window "$name"
  pad_to_canvas "$name"
}

# Single named capture mode.
if [[ $# -eq 1 ]]; then
  shoot "$1"
  exit 0
fi

echo "Current appearance: $(current_appearance)"
echo "This will capture four shots. Switch appearance manually between halves."
echo

for shot in \
  "panel-$(current_appearance | tr '[:upper:]' '[:lower:]')" \
  "settings-$(current_appearance | tr '[:upper:]' '[:lower:]')"
do
  read -r -p "Ready for '$shot'? Open it, then press Return…" _
  shoot "$shot"
done

echo
echo "Now switch System Settings → Appearance to the other mode and re-run:"
echo "  scripts/screenshots.sh"
echo
echo "Expected final set in $OUT_DIR/:"
echo "  panel-light.png  panel-dark.png  settings-light.png  settings-dark.png"
