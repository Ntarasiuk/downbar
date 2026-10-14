import AppKit
import Combine
import Network
import SwiftUI

/// Owns the service list and their latest statuses, runs the poll timer, and
/// fetches all services concurrently. The single source of truth for the UI.
@MainActor
final class StatusMonitor: ObservableObject {
    @Published private(set) var services: [Service]
    @Published private(set) var results: [UUID: ServiceStatusResult] = [:]
    @Published private(set) var isRefreshing = false

    /// Whether the machine currently has no network path. While offline we skip
    /// refreshes entirely rather than flapping every service to `.unknown`.
    @Published private(set) var isOffline = false

    /// Last *known* (non-`.unknown`) indicator per service. Notifications compare
    /// against this rather than the immediately-previous reading, so a transient
    /// unreachable blip doesn't re-fire a "down" alert when the service reappears.
    private var lastKnownIndicator: [UUID: Indicator] = [:]

    /// Poll interval in seconds, persisted in UserDefaults.
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Self.intervalKey)
            scheduleTimer()
        }
    }

    private let store: ServiceStore
    private let history: StatusHistory
    private var timer: Timer?
    private var configWatcher: FileWatcher?

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "downbar.network-path")

    private static let intervalKey = "refreshInterval"
    static let defaultInterval: TimeInterval = 300 // 5 minutes

    init(store: ServiceStore = .shared, history: StatusHistory = .shared) {
        self.store = store
        self.history = history
        self.services = store.load()
        let saved = UserDefaults.standard.double(forKey: Self.intervalKey)
        self.refreshInterval = saved > 0 ? saved : Self.defaultInterval

        // services.json is a supported editing surface (IDE, AI agents): make
        // sure it exists on disk, then hot-reload whenever something else
        // writes it.
        store.ensureOnDisk(services)
        configWatcher = FileWatcher(url: store.fileURL) { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }

        // Begin polling immediately so the menu-bar icon reflects live status
        // at launch, before the dropdown is ever opened.
        if NotificationPrefs.enabled { Notifier.requestAuthorization() }
        startPathMonitor()
        observeWake()
        scheduleTimer()
        Task { await refresh() }
    }

    deinit {
        pathMonitor.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    /// Tracks connectivity. When the network comes back, refresh once so status
    /// recovers without waiting for the next poll tick.
    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = self.isOffline
                self.isOffline = offline
                if wasOffline && !offline { await self.refresh() }
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    /// Re-poll on wake — readings taken before sleep are stale.
    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Re-fetches every service concurrently.
    func refresh() async {
        // No point hammering the network while disconnected, and we don't want
        // to flap everything to `.unknown` — leave the last readings in place.
        guard !isOffline else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let snapshot = services
        let fetched = await withTaskGroup(of: ServiceStatusResult.self) { group in
            for service in snapshot {
                group.addTask {
                    await Self.fetchWithRetry(service)
                }
            }
            var out: [ServiceStatusResult] = []
            for await r in group { out.append(r) }
            return out
        }

        for r in fetched {
            guard let service = snapshot.first(where: { $0.id == r.serviceID }),
                  isCurrent(service) else { continue }
            let old = lastKnownIndicator[r.serviceID]
            results[r.serviceID] = r
            // An unreachable reading isn't a real health change — keep the last
            // known state so a flap doesn't spam alerts, and stay silent.
            guard r.indicator != .unknown else { continue }
            // Record real readings locally to drive the per-service sparkline.
            history.append(serviceID: r.serviceID, indicator: r.indicator, at: r.lastChecked)
            // Only notify after we have a prior known reading, so initial states
            // are silent.
            if let old {
                notifyIfChanged(service, from: old, to: r)
            }
            lastKnownIndicator[r.serviceID] = r.indicator
        }
    }

    /// Dispatches alerts (native notification and/or webhook) when a service
    /// enters or worsens an issue, or recovers.
    private func notifyIfChanged(_ service: Service, from old: Indicator, to result: ServiceStatusResult) {
        // Per-service mute silences every alert channel for that service.
        guard !NotificationPrefs.isMuted(service.id) else { return }
        let new = result.indicator

        let event: WebhookEvent
        if new > old && new > .none {
            // Honor the severity threshold for "down" alerts only.
            guard new >= NotificationPrefs.minSeverity else { return }
            event = .down
        } else if new == .none && old > .none {
            event = .recovered
        } else {
            return
        }

        let (title, body): (String, String) = event == .down
            ? ("\(service.name): \(new.defaultDescription)", result.description)
            : ("\(service.name) recovered", "All Systems Operational")

        // Each channel is independent: webhook works even with native
        // notifications turned off, and vice-versa.
        if NotificationPrefs.enabled {
            Notifier.post(title: title, body: body, url: service.url)
        }
        if WebhookPrefs.isConfigured {
            Webhook.send(event: event, service: service, indicator: new, message: result.description)
        }
    }

    // MARK: - Aggregate

    /// Worst indicator across all services — drives the menu-bar icon.
    var aggregate: Indicator {
        let known = services.compactMap { results[$0.id]?.indicator }
        guard !known.isEmpty else { return .unknown }
        // If we have at least one real (non-unknown) reading, ignore unknowns
        // so a single unreachable service doesn't hide everything.
        let real = known.filter { $0 != .unknown }
        return real.max() ?? .unknown
    }

    func result(for service: Service) -> ServiceStatusResult? {
        results[service.id]
    }

    /// Recent locally-recorded readings for a service, oldest first, for the
    /// sparkline. Empty until at least one successful poll has landed.
    func history(for service: Service) -> [Indicator] {
        history.samples(for: service.id).map { Indicator(rawValue: $0.indicator) ?? .unknown }
    }

    /// One-line headline for the dropdown header, derived from `aggregate`.
    var summary: String {
        if isOffline { return "No connection" }
        switch aggregate {
        case .none: return "All Systems Operational"
        case .minor: return "Some Systems Degraded"
        case .major: return "Partial Service Outage"
        case .critical: return "Major Service Outage"
        case .unknown: return "Status Unavailable"
        }
    }

    /// Most recent successful check across all services.
    var lastUpdated: Date? {
        results.values.map(\.lastChecked).max()
    }

    /// Whether any monitored service uses the AWS adapter (gates the
    /// AWS-region setting, which is meaningless otherwise).
    var monitorsAWS: Bool {
        services.contains { $0.provider == .aws }
    }

    // MARK: - Editing

    /// Re-reads `services.json` after an external edit (an IDE, an AI agent
    /// following the copied prompt) and adopts the differences. Entries that
    /// match a currently monitored service — by id, or by provider + URL when
    /// the file has no id — keep their identity so history and mutes survive.
    /// A no-op when the file matches what's already in memory, which is how
    /// the app's own saves are told apart from external ones.
    func reloadFromDisk() {
        let disk = store.load()
        guard disk != services else { return }

        var usedIDs = Set<UUID>()
        let merged = disk.map { entry -> Service in
            var entry = entry
            let match = services.first { $0.id == entry.id }
                ?? services.first {
                    $0.provider == entry.provider
                        && $0.url.absoluteString.lowercased() == entry.url.absoluteString.lowercased()
                }
            if let match { entry.id = match.id }
            // A hand-duplicated line can repeat an id; identity must stay unique.
            if !usedIDs.insert(entry.id).inserted { entry.id = UUID() }
            return entry
        }

        let oldIDs = Set(services.map(\.id))
        for id in oldIDs.subtracting(merged.map(\.id)) {
            results[id] = nil
            lastKnownIndicator[id] = nil
        }
        let added = merged.filter { !oldIDs.contains($0.id) }
        services = merged
        // Write back the merged list so hand-added entries gain their ids and
        // the file returns to canonical formatting.
        persist()

        Task {
            for service in added { await refreshOne(service) }
        }
    }

    func add(_ service: Service) {
        services.append(service)
        persist()
        Task { await refreshOne(service) }
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets.map { services[$0].id }
        services.remove(atOffsets: offsets)
        for id in removed { results[id] = nil; lastKnownIndicator[id] = nil }
        persist()
    }

    /// Narrows a Statuspage service to specific components (nil/empty = whole page).
    func setComponents(_ ids: [String]?, for service: Service) {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx].components = (ids?.isEmpty ?? true) ? nil : ids
        // The old reading measured a different set of components; comparing
        // against it would fire a false "down" or "recovered" alert.
        lastKnownIndicator[service.id] = nil
        persist()
        let updated = services[idx]
        Task { await refreshOne(updated) }
    }

    func move(from source: IndexSet, to destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Catalog matching

    /// The monitored service corresponding to a catalog entry, if enabled.
    func service(matching entry: CatalogEntry) -> Service? {
        services.first {
            $0.provider == entry.provider && ($0.url.host()?.lowercased() ?? "") == entry.host
        }
    }

    func isMonitored(_ entry: CatalogEntry) -> Bool {
        service(matching: entry) != nil
    }

    /// Toggle a catalog service on/off in the monitored list.
    func setMonitored(_ entry: CatalogEntry, _ enabled: Bool) {
        if enabled {
            guard service(matching: entry) == nil else { return }
            add(Service(name: entry.name, url: entry.url, provider: entry.provider))
        } else if let existing = service(matching: entry),
                  let idx = services.firstIndex(where: { $0.id == existing.id }) {
            remove(at: IndexSet(integer: idx))
        }
    }

    /// Monitored services not present in the catalog (i.e. user-added URLs).
    var customServices: [Service] {
        let catalogIDs = Set(ServiceCatalog.all.map(\.id))
        return services.filter { svc in
            let key = "\(svc.provider.rawValue):\(svc.url.host()?.lowercased() ?? "")"
            return !catalogIDs.contains(key)
        }
    }

    func remove(_ service: Service) {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        remove(at: IndexSet(integer: idx))
    }

    private func refreshOne(_ service: Service) async {
        let r = await Self.fetchWithRetry(service)
        guard isCurrent(service) else { return }
        results[r.serviceID] = r
    }

    /// Whether `service` is still monitored with the same component filter. A
    /// fetch can take seconds (retry included); if the filter changed while it
    /// ran, its reading is for the wrong components and must be dropped.
    private func isCurrent(_ service: Service) -> Bool {
        services.first { $0.id == service.id }?.components == service.components
    }

    /// Fetches a service, retrying once after a short delay if the first read is
    /// `.unknown`. A single transient failure shouldn't gray out a service.
    private static func fetchWithRetry(_ service: Service) async -> ServiceStatusResult {
        let provider = ProviderRegistry.provider(for: service.provider)
        let first = await provider.fetch(service)
        guard first.indicator == .unknown else { return first }
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        return await provider.fetch(service)
    }

    private func persist() {
        store.save(services)
    }
}
