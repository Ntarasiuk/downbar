import SwiftUI

/// The panel shown from the menu-bar icon. Modeled on Control Center: a status
/// header with the aggregate summary, a scrollable list of service rows, and a
/// quiet footer of actions.
struct MenuContent: View {
    @ObservedObject var monitor: StatusMonitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            serviceList
            Divider()
            footer
        }
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: monitor.aggregate.symbolName)
                .font(.system(size: 22))
                .foregroundStyle(monitor.aggregate.color)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(monitor.summary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(updatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            // Read the aggregate summary and freshness as a single header element.
            .accessibilityElement(children: .combine)

            Spacer(minLength: 6)

            RefreshButton(monitor: monitor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var updatedText: String {
        guard let updated = monitor.lastUpdated else {
            return String(localized: "Checking…")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: updated, relativeTo: Date())
        return String(localized: "Updated \(relative)")
    }

    // MARK: - Service list

    private var serviceList: some View {
        let groups = groupedServices
        return ScrollView {
            VStack(spacing: 2) {
                ForEach(groups.affected) { service in
                    ServiceRow(service: service,
                               result: monitor.result(for: service),
                               history: monitor.history(for: service))
                }
                if !groups.affected.isEmpty && !groups.healthy.isEmpty {
                    Divider()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .accessibilityHidden(true)
                }
                ForEach(groups.healthy) { service in
                    ServiceRow(service: service,
                               result: monitor.result(for: service),
                               history: monitor.history(for: service))
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 480)
    }

    /// Services with an active issue (minor/major/critical) sorted worst-first,
    /// separated from everything else (operational or not-yet-/un-reachable).
    private var groupedServices: (affected: [Service], healthy: [Service]) {
        var affected: [Service] = []
        var healthy: [Service] = []
        for service in monitor.services {
            let indicator = monitor.result(for: service)?.indicator ?? .unknown
            if indicator > .none {
                affected.append(service)
            } else {
                healthy.append(service)
            }
        }
        affected.sort {
            (monitor.result(for: $0)?.indicator ?? .unknown)
                > (monitor.result(for: $1)?.indicator ?? .unknown)
        }
        return (affected, healthy)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(title: "Settings", systemImage: "gearshape") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            FooterButton(title: "Quit", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}

/// Circular refresh control in the header; shows a spinner while a fetch is in
/// flight.
private struct RefreshButton: View {
    @ObservedObject var monitor: StatusMonitor
    @State private var hovering = false

    var body: some View {
        Button {
            Task { await monitor.refresh() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(hovering ? 0.1 : 0))
                    .frame(width: 26, height: 26)
                if monitor.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(monitor.isRefreshing)
        .onHover { hovering = $0 }
        .keyboardShortcut("r")
        .help("Refresh now")
        .accessibilityLabel("Refresh now")
        .accessibilityValue(monitor.isRefreshing ? "Refreshing" : "")
    }
}

/// Quiet, full-width footer action with a hover highlight.
private struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
    }
}
