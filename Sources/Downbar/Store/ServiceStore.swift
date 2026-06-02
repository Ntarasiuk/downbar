import Foundation

/// Persists the monitored-service list as `services.json` in
/// `~/Library/Application Support/Downbar/`. Seeds a default list on first launch.
final class ServiceStore: Sendable {
    static let shared = ServiceStore()

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Downbar", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("services.json")
    }

    func load() -> [Service] {
        guard let data = try? Data(contentsOf: fileURL),
              let services = try? JSONDecoder().decode([Service].self, from: data),
              !services.isEmpty else {
            return Self.seed
        }
        return services
    }

    func save(_ services: [Service]) {
        guard let data = try? JSONEncoder().encode(services) else { return }
        try? data.write(to: fileURL, options: .atomic)
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
