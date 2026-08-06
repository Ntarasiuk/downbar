import AppKit
import SwiftUI
import ServiceManagement

/// Two-tab preferences: pick which services to monitor (from a curated catalog
/// or a custom URL), and general app preferences.
struct SettingsView: View {
    @ObservedObject var monitor: StatusMonitor

    var body: some View {
        TabView {
            ServicesTab(monitor: monitor)
                .tabItem { Label("Services", systemImage: "square.grid.2x2") }
            GeneralTab(monitor: monitor)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 500, height: 580)
    }
}

// MARK: - Services tab

private struct ServicesTab: View {
    @ObservedObject var monitor: StatusMonitor
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Choose the services you want to monitor.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                SearchField(text: $search)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            List {
                if search.isEmpty && monitor.services.count > 1 {
                    Section("Monitored (drag to reorder)") {
                        ForEach(monitor.services) { service in
                            ReorderRow(monitor: monitor, service: service)
                        }
                        .onMove { source, destination in
                            monitor.move(from: source, to: destination)
                        }
                    }
                }

                ForEach(ServiceCatalog.categories, id: \.self) { category in
                    let entries = filtered(ServiceCatalog.entries(in: category))
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                CatalogRow(monitor: monitor, entry: entry)
                            }
                        } header: {
                            CategoryHeader(monitor: monitor, title: category, entries: entries)
                        }
                    }
                }

                let customs = filteredCustom
                if !customs.isEmpty {
                    Section("Custom") {
                        ForEach(customs) { service in
                            CustomRow(monitor: monitor, service: service)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if hasNoResults {
                    ContentUnavailableView.search(text: search)
                }
            }

            Divider()
            CustomAddForm(monitor: monitor)
                .padding(16)
            Divider()
            AgentImportRow(monitor: monitor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    private func filtered(_ entries: [CatalogEntry]) -> [CatalogEntry] {
        guard !search.isEmpty else { return entries }
        let q = search.lowercased()
        return entries.filter { $0.name.lowercased().contains(q) || $0.host.contains(q) }
    }

    private var filteredCustom: [Service] {
        guard !search.isEmpty else { return monitor.customServices }
        let q = search.lowercased()
        return monitor.customServices.filter {
            $0.name.lowercased().contains(q) || ($0.url.host()?.lowercased().contains(q) ?? false)
        }
    }

    private var hasNoResults: Bool {
        guard !search.isEmpty else { return false }
        let noCatalog = ServiceCatalog.categories.allSatisfy {
            filtered(ServiceCatalog.entries(in: $0)).isEmpty
        }
        return noCatalog && filteredCustom.isEmpty
    }
}

/// Rounded search field matching the macOS settings aesthetic.
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search services", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .accessibilityLabel("Search services")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// A section header with the category name and a button to enable or disable
/// every (currently visible) service in that category at once.
private struct CategoryHeader: View {
    @ObservedObject var monitor: StatusMonitor
    let title: String
    let entries: [CatalogEntry]

    private var allMonitored: Bool {
        entries.allSatisfy { monitor.isMonitored($0) }
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(allMonitored ? "Deselect all" : "Select all") {
                let enable = !allMonitored
                for entry in entries {
                    monitor.setMonitored(entry, enable)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.tint)
            .textCase(nil)
        }
    }
}

/// A catalog service with a switch to enable/disable monitoring.
private struct CatalogRow: View {
    @ObservedObject var monitor: StatusMonitor
    let entry: CatalogEntry

    var body: some View {
        let monitored = monitor.service(matching: entry)
        let indicator = monitored.flatMap { monitor.result(for: $0)?.indicator }

        Toggle(isOn: Binding(
            get: { monitor.isMonitored(entry) },
            set: { monitor.setMonitored(entry, $0) }
        )) {
            HStack(spacing: 10) {
                Image(systemName: (indicator ?? .none).symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(indicator?.color ?? .secondary.opacity(0.4))
                    .frame(width: 16)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name).font(.system(size: 13))
                    Text(entry.host).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if let id = monitored?.id {
                    Spacer()
                    MuteButton(serviceID: id)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .accessibilityLabel("Monitor \(entry.name)")
    }
}

/// Subtle bell toggle that mutes notifications for a single monitored service.
private struct MuteButton: View {
    let serviceID: UUID
    @State private var muted: Bool

    init(serviceID: UUID) {
        self.serviceID = serviceID
        _muted = State(initialValue: NotificationPrefs.isMuted(serviceID))
    }

    var body: some View {
        Button {
            muted.toggle()
            NotificationPrefs.setMuted(serviceID, muted)
        } label: {
            Image(systemName: muted ? "bell.slash.fill" : "bell")
                .font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(muted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .help(muted ? "Notifications muted" : "Mute notifications")
        .accessibilityLabel(muted ? "Unmute notifications" : "Mute notifications")
    }
}

/// A user-added (non-catalog) service with a remove button.
private struct CustomRow: View {
    @ObservedObject var monitor: StatusMonitor
    let service: Service

    var body: some View {
        let indicator = monitor.result(for: service)?.indicator ?? .unknown
        HStack(spacing: 10) {
            Image(systemName: indicator.symbolName)
                .font(.system(size: 13))
                .foregroundStyle(indicator.color)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(service.name).font(.system(size: 13))
                Text(service.url.host() ?? service.url.absoluteString)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            MuteButton(serviceID: service.id)
            Button(role: .destructive) {
                monitor.remove(service)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove \(service.name)")
            .accessibilityLabel("Remove \(service.name)")
        }
    }
}

/// A compact, drag-reorderable row for a currently monitored service.
private struct ReorderRow: View {
    @ObservedObject var monitor: StatusMonitor
    let service: Service

    var body: some View {
        let indicator = monitor.result(for: service)?.indicator ?? .unknown
        HStack(spacing: 10) {
            Image(systemName: indicator.symbolName)
                .font(.system(size: 13))
                .foregroundStyle(indicator.color)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(service.name).font(.system(size: 13))
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(service.name)
    }
}

/// Compact form for adding a status page that isn't in the catalog.
private struct CustomAddForm: View {
    @ObservedObject var monitor: StatusMonitor

    @State private var name = ""
    @State private var urlText = ""
    @State private var provider: ProviderKind = .statuspage
    @State private var error: String?
    @State private var isValidating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a Custom Service").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                TextField("Name", text: $name).frame(width: 110)
                TextField(urlPlaceholder, text: $urlText)
                Picker("", selection: $provider) {
                    ForEach(ProviderKind.customAddable) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
                Button(isValidating ? "Checking…" : "Add") {
                    Task { await add() }
                }
                .disabled(name.isEmpty || urlText.isEmpty || isValidating)
            }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            } else {
                Text(provider == .website
                     ? "Pings any site or server over HTTP — reports online/offline with latency."
                     : "Paste a public status page; Downbar reads its live feed.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var urlPlaceholder: String {
        provider == .website ? "https://example.com or your server URL" : "Status page URL"
    }

    private func add() async {
        error = nil
        guard var url = URL(string: urlText.trimmingCharacters(in: .whitespaces)), url.host != nil || url.scheme == nil else {
            error = String(localized: "Invalid URL"); return
        }
        if url.scheme == nil { url = URL(string: "https://\(urlText.trimmingCharacters(in: .whitespaces))") ?? url }
        guard url.host != nil else { error = String(localized: "Invalid URL"); return }

        // Validate status-feed providers up front; a website check is allowed
        // even when currently down (that's a valid thing to want to watch).
        if provider == .statuspage || provider == .instatus {
            isValidating = true
            defer { isValidating = false }
            let probe = Service(name: name, url: url, provider: provider)
            let r = await ProviderRegistry.provider(for: provider).fetch(probe)
            if r.indicator == .unknown {
                error = String(localized: "Couldn't read a \(provider.displayName) feed there (\(r.description))"); return
            }
        }

        monitor.add(Service(name: name.trimmingCharacters(in: .whitespaces), url: url, provider: provider))
        name = ""; urlText = ""; provider = .statuspage
    }
}

/// Lets an AI coding agent fill the service list from a real codebase: copy a
/// generated prompt into Claude Code / Cursor / etc., or open `services.json`
/// directly in an editor. The app hot-reloads the file on save.
private struct AgentImportRow: View {
    @ObservedObject var monitor: StatusMonitor
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add from a Codebase").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                Button {
                    copyPrompt()
                } label: {
                    Label(copied ? "Copied" : "Copy AI Prompt",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 110)
                }
                Button("Edit services.json") { openConfig() }
                Spacer()
            }
            Text("Paste the prompt into Claude Code, Cursor, or any coding agent opened in a project — it finds the services the code depends on, plus your own production URLs, and adds them here. The config is plain JSON; edits apply instantly.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func copyPrompt() {
        // The prompt tells the agent to edit this file, so it must exist.
        ServiceStore.shared.ensureOnDisk(monitor.services)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(AgentPrompt.text(), forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }

    private func openConfig() {
        ServiceStore.shared.ensureOnDisk(monitor.services)
        NSWorkspace.shared.open(ServiceStore.shared.fileURL)
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @ObservedObject var monitor: StatusMonitor
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var regions = AWSRegionFilter.selected
    @State private var notify = NotificationPrefs.enabled
    @State private var minSeverity = NotificationPrefs.minSeverity
    @State private var webhookURL = WebhookPrefs.urlString
    @State private var webhookTesting = false
    @State private var webhookTestOK: Bool?
    @State private var showingRegions = false

    var body: some View {
        Form {
            Section {
                Picker("Refresh every", selection: $monitor.refreshInterval) {
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
            }

            Section {
                Toggle("Notify when a service goes down", isOn: $notify)
                    .onChange(of: notify) { _, newValue in
                        NotificationPrefs.enabled = newValue
                        if newValue { Notifier.requestAuthorization() }
                    }

                if notify {
                    Picker("Notify me about", selection: $minSeverity) {
                        Text("Any issue").tag(Indicator.minor)
                        Text("Major outages").tag(Indicator.major)
                        Text("Critical only").tag(Indicator.critical)
                    }
                    .onChange(of: minSeverity) { _, newValue in
                        NotificationPrefs.minSeverity = newValue
                    }
                }
            } footer: {
                Text("Get a notification when a monitored service starts having issues or recovers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Webhook URL", text: $webhookURL, prompt: Text("https://hooks.slack.com/… or any endpoint"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: webhookURL) { _, newValue in
                        WebhookPrefs.urlString = newValue
                        webhookTestOK = nil
                    }
                HStack {
                    Button(webhookTesting ? "Sending…" : "Send test") {
                        Task { await sendWebhookTest() }
                    }
                    .disabled(WebhookPrefs.url == nil || webhookTesting)

                    if let ok = webhookTestOK {
                        Label(ok ? "Delivered" : "Failed — check the URL",
                              systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ok ? .green : .red)
                    }
                    Spacer()
                }
            } header: {
                Text("Alerts webhook")
            } footer: {
                Text("POST a JSON alert (with Slack `text` and Discord `content` fields) to this URL on the same up/down transitions. Works even if notifications are off; respects per-service mute and the severity threshold.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if monitor.monitorsAWS {
                Section {
                    Button {
                        showingRegions = true
                    } label: {
                        LabeledContent("AWS Regions", value: regionsSummary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingRegions, arrowEdge: .bottom) {
                        AWSRegionPicker(selected: $regions, onChange: persist)
                    }
                } footer: {
                    Text("Only count AWS incidents in the selected regions. Global services (Route 53, IAM, CloudFront…) always count. Leave all unchecked to monitor every region.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sendWebhookTest() async {
        guard let url = WebhookPrefs.url else { return }
        webhookTesting = true
        webhookTestOK = nil
        let ok = await Webhook.sendTest(to: url)
        webhookTesting = false
        webhookTestOK = ok
    }

    private var regionsSummary: String {
        regions.isEmpty
            ? String(localized: "All regions")
            : String(localized: "\(regions.count) selected")
    }

    private func persist() {
        AWSRegionFilter.selected = regions
        Task { await monitor.refresh() }
    }
}

/// A stay-open checklist for multi-selecting AWS regions, grouped by geography.
/// An empty selection means "all regions".
private struct AWSRegionPicker: View {
    @Binding var selected: Set<String>
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AWS Regions")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Monitor all") {
                    selected = []
                    onChange()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.tint)
                .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(AWSRegionFilter.groups, id: \.title) { group in
                        Text(group.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 3)

                        ForEach(group.regions, id: \.code) { region in
                            RegionRow(region: region,
                                      isOn: selected.contains(region.code)) {
                                toggle(region.code)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: 290, height: 400)
    }

    private func toggle(_ code: String) {
        if selected.contains(code) { selected.remove(code) } else { selected.insert(code) }
        onChange()
    }
}

/// One tappable region row with a checkmark; the popover stays open so several
/// can be selected in a row.
private struct RegionRow: View {
    let region: AWSRegionFilter.Region
    let isOn: Bool
    let toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 9) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .font(.system(size: 13))
                    .accessibilityHidden(true)
                Text(region.code)
                    .font(.system(size: 12, weight: .medium))
                Text(region.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(Color.primary.opacity(hovering ? 0.06 : 0))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(region.code), \(region.name)")
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+) for launch-at-login.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Downbar: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }
}
