import SwiftUI

/// One row in the panel: a colored status glyph, the service name, its current
/// description, and a relative last-checked age. Hover reveals an open-in-browser
/// affordance and a soft highlight; clicking opens the public status page.
struct ServiceRow: View {
    let service: Service
    let result: ServiceStatusResult?
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(service.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: indicator.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(indicator.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(service.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if hovering {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(ageText)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open \(service.url.host() ?? service.name)")
    }

    private var indicator: Indicator { result?.indicator ?? .unknown }

    private var description: String {
        // An active incident's title is more specific than the generic status.
        result?.incidentTitle ?? result?.description ?? "Checking…"
    }

    private var ageText: String {
        guard let checked = result?.lastChecked else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: checked, relativeTo: Date())
    }
}
