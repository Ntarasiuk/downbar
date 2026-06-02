import Foundation

/// Persists a rolling window of recent status readings per service as
/// `history.json` in `~/Library/Application Support/Downbar/`. Storage is
/// strictly local — nothing is ever transmitted. Used to draw a sparkline of
/// each service's recent health.
///
/// `@MainActor` because it's read and written from `StatusMonitor`, which is
/// itself main-actor isolated.
@MainActor
final class StatusHistory {
    static let shared = StatusHistory()

    /// One recorded reading: an `Indicator.rawValue` and when it was taken.
    struct Sample: Codable {
        let indicator: Int
        let at: Date
    }

    /// Keep the file small: at most this many samples per service, and drop
    /// anything older than a week — whichever bound bites first.
    private static let maxSamples = 96
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    private let fileURL: URL
    private var samplesByService: [UUID: [Sample]]

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Downbar", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([UUID: [Sample]].self, from: data) {
            self.samplesByService = decoded
        } else {
            self.samplesByService = [:]
        }
    }

    /// Records one reading, trims the window, and persists.
    func append(serviceID: UUID, indicator: Indicator, at date: Date = Date()) {
        var window = samplesByService[serviceID] ?? []
        window.append(Sample(indicator: indicator.rawValue, at: date))
        samplesByService[serviceID] = Self.trim(window, now: date)
        save()
    }

    /// Recent readings for a service, oldest first, already trimmed to the window.
    func samples(for serviceID: UUID) -> [Sample] {
        Self.trim(samplesByService[serviceID] ?? [], now: Date())
    }

    /// Drops stale samples then caps the count, keeping the most recent.
    private static func trim(_ samples: [Sample], now: Date) -> [Sample] {
        let cutoff = now.addingTimeInterval(-maxAge)
        let fresh = samples.filter { $0.at >= cutoff }
        return fresh.count > maxSamples ? Array(fresh.suffix(maxSamples)) : fresh
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(samplesByService) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
