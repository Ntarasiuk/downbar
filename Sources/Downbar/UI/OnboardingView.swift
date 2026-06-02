import SwiftUI

/// A one-screen, first-run intro explaining the menu-bar meter and pointing
/// the user to Settings to choose which services to monitor.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Welcome to Downbar")
                    .font(.system(size: 20, weight: .semibold))
                Text("Downbar lives in your menu bar and keeps an eye on the services you depend on.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                MeterLegend(indicator: .none, text: "Healthy — everything is operational.")
                MeterLegend(indicator: .minor, text: "Degraded — minor issues or maintenance.")
                MeterLegend(indicator: .critical, text: "Outage — a service is down.")
                MeterLegend(indicator: .unknown, text: "Unreachable — Downbar can’t reach the feed.")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Text("Open Settings to choose which services to watch.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Not Now") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Choose Services") {
                    dismiss()
                    openSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 380)
    }
}

/// A single colored meter swatch paired with its description.
private struct MeterLegend: View {
    let indicator: Indicator
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: indicator.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(indicator.color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
        }
    }
}
