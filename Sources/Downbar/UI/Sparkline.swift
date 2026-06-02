import SwiftUI

/// A compact horizontal strip of colored segments — one per recent reading,
/// oldest at the leading edge — giving an at-a-glance sense of a service's
/// recent health. Degrades quietly: shows nothing when there's no history.
struct Sparkline: View {
    let samples: [Indicator]

    /// At most this many segments, keeping the strip narrow in the row.
    private static let maxSegments = 16
    private static let segmentWidth: CGFloat = 2
    private static let segmentSpacing: CGFloat = 1

    /// Constant width the strip always occupies, so the trailing age/affordance
    /// column never shifts as history accumulates or differs between rows.
    private static let reservedWidth =
        CGFloat(maxSegments) * segmentWidth + CGFloat(maxSegments - 1) * segmentSpacing

    var body: some View {
        // Newest segments hug the trailing edge (next to the age) and grow
        // leftward within the fixed box, so neighbours never reflow.
        HStack(spacing: Self.segmentSpacing) {
            ForEach(Array(recent.enumerated()), id: \.offset) { _, indicator in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(indicator.color.opacity(0.7))
                    .frame(width: Self.segmentWidth)
            }
        }
        .frame(width: Self.reservedWidth, height: 12, alignment: .trailing)
    }

    /// The most recent samples, capped to keep the strip small.
    private var recent: [Indicator] {
        samples.suffix(Self.maxSegments).map { $0 }
    }
}
