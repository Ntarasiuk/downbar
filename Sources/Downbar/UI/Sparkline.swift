import SwiftUI

/// A compact horizontal strip of colored segments — one per recent reading,
/// oldest at the leading edge — giving an at-a-glance sense of a service's
/// recent health. Degrades quietly: shows nothing when there's no history.
struct Sparkline: View {
    let samples: [Indicator]

    /// At most this many segments, keeping the strip narrow in the row.
    private static let maxSegments = 16

    var body: some View {
        if recent.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 1) {
                ForEach(Array(recent.enumerated()), id: \.offset) { _, indicator in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(indicator.color.opacity(0.7))
                        .frame(width: 2)
                }
            }
            .frame(height: 12)
        }
    }

    /// The most recent samples, capped to keep the strip small.
    private var recent: [Indicator] {
        samples.suffix(Self.maxSegments).map { $0 }
    }
}
