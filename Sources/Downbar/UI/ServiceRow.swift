import SwiftUI

/// One row in the panel: a colored status glyph, the service name, its current
/// description, and a relative last-checked age. Hover reveals an open-in-browser
/// affordance and a soft highlight; clicking opens the public status page.
struct ServiceRow: View {
    let service: Service
    let result: ServiceStatusResult?
    /// Recent readings, oldest first, for the trailing sparkline. Defaults to
    /// empty so the row renders fine before any history is supplied.
    var history: [Indicator] = []
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(service.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: glyphName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(glyphColor)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(service.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Sparkline(samples: history)
                    .accessibilityHidden(true)

                if hovering {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                } else {
                    Text(ageText)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
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
        // Collapse the glyph, sparkline, and age into one spoken element so the
        // row announces "{name}, {status}, updated {age}" instead of reading the
        // decorative pieces as separate noise.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the status page")
    }

    /// One-line VoiceOver summary for the whole row.
    private var accessibilityLabel: String {
        var parts = [service.name, description]
        if isMaintenance { parts.append(String(localized: "under maintenance")) }
        if !ageText.isEmpty { parts.append(String(localized: "updated \(ageText)")) }
        return parts.joined(separator: ", ")
    }

    private var indicator: Indicator { result?.indicator ?? .unknown }

    /// A maintenance window is planned work, not an outage — quiet it down.
    private var isMaintenance: Bool { result?.isMaintenance ?? false }

    /// Distinct maintenance glyph so a service under maintenance doesn't read
    /// as a warning; otherwise the indicator's own symbol.
    private var glyphName: String {
        isMaintenance ? "wrench.and.screwdriver.fill" : indicator.symbolName
    }

    private var glyphColor: Color {
        isMaintenance ? .secondary : indicator.color
    }

    private var description: String {
        // Maintenance reads calmer than the generic "degraded" wording.
        if isMaintenance { return result?.incidentTitle ?? String(localized: "Under Maintenance") }
        // An active incident's title is more specific than the generic status.
        return result?.incidentTitle ?? result?.description ?? String(localized: "Checking…")
    }

    private var ageText: String {
        guard let checked = result?.lastChecked else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: checked, relativeTo: Date())
    }
}
