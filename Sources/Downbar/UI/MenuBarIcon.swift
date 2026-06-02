import SwiftUI
import AppKit

/// Downbar's custom menu-bar glyph: three ascending rounded bars (a status
/// meter) tinted by the worst current indicator. Reads as a health gauge —
/// green when all is well, amber when degraded, red during an outage, and a
/// dimmed gray when status can't be determined.
struct MenuBarIcon: View {
    let indicator: Indicator

    // Bar heights in points, drawn from a common baseline.
    private let heights: [CGFloat] = [7, 11, 15]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(heights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .frame(width: 3.5, height: heights[i])
                    .opacity(barOpacity(i))
            }
        }
        .foregroundStyle(indicator.color)
        .frame(width: 18, height: 16, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Downbar — \(accessibilityState)")
    }

    /// Spoken description of the current aggregate health, so the menu-bar item
    /// announces "All Systems Operational", "Major Outage", etc. rather than a
    /// generic "Service status".
    private var accessibilityState: String {
        indicator == .none ? String(localized: "All systems operational") : indicator.defaultDescription
    }

    /// When everything is healthy all three bars are solid; degraded/outage
    /// states fade the shorter bars slightly so the tallest bar reads as the
    /// "alert" level — a subtle cue beyond color alone.
    private func barOpacity(_ index: Int) -> Double {
        switch indicator {
        case .none: return 1.0
        case .unknown: return 0.45
        case .minor: return index == 0 ? 0.5 : 1.0
        case .major, .critical: return Double(index) * 0.3 + 0.4
        }
    }
}

/// Rasterizes `MenuBarIcon` to a non-template `NSImage` so the status color is
/// preserved in the menu bar (SwiftUI shape views used directly as a
/// `MenuBarExtra` label render unreliably / monochrome).
@MainActor
enum MenuBarIconRenderer {
    static func nsImage(for indicator: Indicator) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarIcon(indicator: indicator))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else {
            return NSImage(size: NSSize(width: 18, height: 16))
        }
        image.isTemplate = false   // keep our status color, don't tint to menu-bar mono
        return image
    }
}
