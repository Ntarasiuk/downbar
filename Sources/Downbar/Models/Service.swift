import Foundation

/// Which status-page format a service exposes, and therefore which
/// `StatusProvider` adapter the monitor dispatches to.
enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case statuspage
    case instatus
    case website
    case aws
    case apple
    case gcp
    case azure
    case xai
    case statusio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .statuspage: return "Statuspage.io"
        case .instatus: return "Instatus"
        case .website: return "Website / Server"
        case .aws: return "AWS Health"
        case .apple: return "Apple System Status"
        case .gcp: return "Google Cloud Status"
        case .azure: return "Azure Status"
        case .xai: return "xAI Status"
        case .statusio: return "Status.io"
        }
    }

    /// Provider kinds that make sense to add by hand (the rest are fixed-feed
    /// singletons already in the catalog).
    static let customAddable: [ProviderKind] = [.statuspage, .instatus, .website]
}

/// A monitored service: a public status page plus the adapter that reads it.
struct Service: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// The public status page URL (also what we open when a row is clicked).
    var url: URL
    var provider: ProviderKind
    /// Statuspage component IDs to watch (e.g. one Cloudflare data center).
    /// nil or empty = the page's overall status.
    var components: [String]?

    init(id: UUID = UUID(), name: String, url: URL, provider: ProviderKind = .statuspage, components: [String]? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.provider = provider
        self.components = components
    }

    /// Lenient decoding so `services.json` stays hand- and AI-editable:
    /// `id` and `provider` are optional (a new entry is just name + url),
    /// and a malformed `id` becomes a fresh one instead of an error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.url = try c.decode(URL.self, forKey: .url)
        self.provider = (try? c.decode(ProviderKind.self, forKey: .provider)) ?? .statuspage
        self.components = try? c.decodeIfPresent([String].self, forKey: .components)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, url, provider, components
    }
}
