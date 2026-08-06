import Foundation

/// Persists the monitored-service list as `services.json` in
/// `~/Library/Application Support/Downbar/`. Seeds a default list on first launch.
///
/// The file is a supported editing surface, not just an implementation detail:
/// users (and AI agents pointed at it via the Settings prompt) can edit it in
/// any editor and the app picks the change up live. Decoding is therefore
/// per-entry lossy — one malformed entry is dropped, never the whole list —
/// and saves are pretty-printed so the file stays diffable and hand-editable.
final class ServiceStore: Sendable {
    static let shared = ServiceStore()

    let fileURL: URL

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        let dir = directory ?? {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return base.appendingPathComponent("Downbar", isDirectory: true)
        }()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("services.json")
    }

    func load() -> [Service] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Lossy<Service>].self, from: data) else {
            return Self.seed
        }
        // Drop exact re-adds (same provider + URL) so an agent appending an
        // entry that already exists is harmless and idempotent.
        var seen = Set<String>()
        let services = decoded.compactMap(\.value).filter {
            seen.insert("\($0.provider.rawValue):\($0.url.absoluteString.lowercased())").inserted
        }
        return services.isEmpty ? Self.seed : services
    }

    func save(_ services: [Service]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(services) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Writes the current list if the file doesn't exist yet, so there is
    /// always a real file for editors and agents to open and append to.
    func ensureOnDisk(_ services: [Service]) {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        save(services)
    }

    /// Decodes to `nil` instead of failing, so one bad entry in a hand-edited
    /// file doesn't wipe out the rest of the list.
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) { value = try? T(from: decoder) }
    }

    /// First-launch defaults, using endpoints verified live (2026-06-02).
    static let seed: [Service] = [
        Service(name: "Vercel", url: URL(string: "https://www.vercel-status.com")!, provider: .statuspage),
        Service(name: "Cloudflare", url: URL(string: "https://www.cloudflarestatus.com")!, provider: .statuspage),
        Service(name: "Stripe", url: URL(string: "https://www.stripestatus.com")!, provider: .statuspage),
        Service(name: "GitHub", url: URL(string: "https://www.githubstatus.com")!, provider: .statuspage),
        Service(name: "Anthropic", url: URL(string: "https://status.claude.com")!, provider: .statuspage),
        Service(name: "OpenAI", url: URL(string: "https://status.openai.com")!, provider: .statuspage),
        Service(name: "AWS", url: URL(string: "https://health.aws.amazon.com/health/status")!, provider: .aws),
        Service(name: "Apple Developer", url: URL(string: "https://developer.apple.com/system-status/")!, provider: .apple),
    ]
}
