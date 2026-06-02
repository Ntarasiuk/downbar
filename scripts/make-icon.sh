#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from Downbar's motif: three ascending rounded
# bars (a status meter) in green on a rounded-rect background — mirroring
# Sources/Downbar/UI/MenuBarIcon.swift. Fully reproducible: renders a 1024x1024
# master PNG via a throwaway single-file Swift program (CoreGraphics), then uses
# sips + iconutil to build the standard .iconset and pack the .icns.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_PNG="Resources/AppIcon-1024.png"
ICONSET="Resources/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"
GEN_SRC="$(mktemp -t downbar-icon-XXXXXX).swift"
trap 'rm -f "$GEN_SRC"' EXIT

cat > "$GEN_SRC" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

// Renders the 1024x1024 app-icon master PNG. The motif matches MenuBarIcon:
// three ascending rounded bars on a rounded-rect "app tile" background. Green
// is `.none` / "All Systems Operational" — Downbar's resting, healthy state.

let side: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(side), height: Int(side),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("could not create CGContext") }

// Rounded-rect tile background with a subtle vertical gradient so the green
// bars read with depth rather than flat. macOS icons sit on ~18% corner radius.
let inset: CGFloat = side * 0.06
let tile = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let corner = tile.width * 0.225
let tilePath = CGPath(roundedRect: tile, cornerWidth: corner, cornerHeight: corner, transform: nil)

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bgColors = [
    CGColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0),
    CGColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1.0),
] as CFArray
if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])
}
ctx.restoreGState()

// Three ascending bars. Heights mirror MenuBarIcon's [7, 11, 15] ratio; widths
// and spacing scaled to fill the tile pleasingly. Drawn from a shared baseline.
let green = CGColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0) // systemGreen-ish

let ratios: [CGFloat] = [7, 11, 15]
let maxRatio = ratios.max()!
let content = tile.insetBy(dx: tile.width * 0.20, dy: tile.height * 0.20)
let barW = content.width * 0.20
let gap = (content.width - barW * 3) / 2
let baseline = content.minY
let barCorner = barW * 0.32

for (i, r) in ratios.enumerated() {
    let h = content.height * (r / maxRatio)
    let x = content.minX + CGFloat(i) * (barW + gap)
    let rect = CGRect(x: x, y: baseline, width: barW, height: h)
    let path = CGPath(roundedRect: rect, cornerWidth: barCorner, cornerHeight: barCorner, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(green)
    ctx.fillPath()
}

guard let image = ctx.makeImage() else { fatalError("could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
SWIFT

echo "==> Rendering ${OUT_PNG} (1024x1024)"
swift "$GEN_SRC" "$OUT_PNG"

if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
  echo "warning: sips/iconutil unavailable — produced ${OUT_PNG} only; skipping .icns" >&2
  exit 0
fi

echo "==> Building ${ICONSET}"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# Standard macOS iconset matrix: 16/32/128/256/512 at @1x and @2x.
emit() { # <pt-size> <scale-suffix> <pixels> <filename>
  sips -z "$3" "$3" "$OUT_PNG" --out "${ICONSET}/$4" >/dev/null
}
emit  16 1x   16 "icon_16x16.png"
emit  16 2x   32 "icon_16x16@2x.png"
emit  32 1x   32 "icon_32x32.png"
emit  32 2x   64 "icon_32x32@2x.png"
emit 128 1x  128 "icon_128x128.png"
emit 128 2x  256 "icon_128x128@2x.png"
emit 256 1x  256 "icon_256x256.png"
emit 256 2x  512 "icon_256x256@2x.png"
emit 512 1x  512 "icon_512x512.png"
emit 512 2x 1024 "icon_512x512@2x.png"

echo "==> Packing ${ICNS}"
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "==> Done: ${ICNS}"
