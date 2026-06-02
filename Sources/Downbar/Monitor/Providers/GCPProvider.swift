import Foundation

/// Reads Google Cloud's public incident feed:
///   GET https://status.cloud.google.com/incidents.json
/// A JSON array of incidents (active + historical). An incident is *active*
/// while it has no `end` timestamp. Severity comes from `status_impact`.
struct GCPProvider: StatusProvider {
    private static let feed = URL(string: "https://status.cloud.google.com/incidents.json")!

    private struct Incident: Decodable {
        let end: String?
        let external_desc: String?
        let status_impact: String?
        let severity: String?
        let affected_products: [Product]?

        struct Product: Decodable { let title: String? }
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = GCPProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        do {
            let (data, response) = try await session.data(from: Self.feed)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let incidents = try JSONDecoder().decode([Incident].self, from: data)

            // Active = no end timestamp.
            let active = incidents.filter { ($0.end ?? "").isEmpty }
            guard !active.isEmpty else {
                return result(service, .none, "All Systems Operational")
            }

            let worst = active.map { Self.indicator(for: $0) }.max() ?? .major
            let lead = active.first { Self.indicator(for: $0) == worst }
            let desc = lead?.external_desc ?? worst.defaultDescription
            let product = lead?.affected_products?.first?.title.map { " — \($0)" } ?? ""
            let more = active.count > 1 ? " (+\(active.count - 1) more)" : ""
            return result(service, worst, "\(desc)\(product)\(more)")
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    private static func indicator(for incident: Incident) -> Indicator {
        switch incident.status_impact {
        case "SERVICE_OUTAGE": return .critical
        case "SERVICE_DISRUPTION": return .major
        case "SERVICE_INFORMATION": return .minor
        default:
            switch incident.severity {
            case "high": return .critical
            case "medium": return .major
            default: return .minor
            }
        }
    }
}
