import Foundation

/// Reads the Instatus uniform endpoint:
///   GET https://<host>/summary.json
///   → { "page": { "status": "UP|HASISSUES|UNDERMAINTENANCE" },
///       "activeIncidents": [ { "name", "impact" } ],
///       "activeMaintenances": [ ... ] }
/// Instatus is the second-most-common public status format (Perplexity, xAI,
/// Recraft, and many others). One adapter covers them all.
struct InstatusProvider: StatusProvider {
    private struct Summary: Decodable {
        struct Page: Decodable { let status: String? }
        struct Incident: Decodable { let name: String?; let impact: String? }
        let page: Page
        let activeIncidents: [Incident]?
        let activeMaintenances: [Incident]?
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = InstatusProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        guard let endpoint = InstatusProvider.summaryEndpoint(for: service.url) else {
            return unknown(service, "Invalid URL")
        }
        do {
            let (data, response) = try await session.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let summary = try JSONDecoder().decode(Summary.self, from: data)

            let incidents = summary.activeIncidents ?? []
            let maintenances = summary.activeMaintenances ?? []
            let status = (summary.page.status ?? "").uppercased()

            // Worst across active incidents, then factor in maintenance / page status.
            var worst = incidents.map { Self.indicator(impact: $0.impact) }.max() ?? .none
            if !maintenances.isEmpty { worst = max(worst, .minor) }
            if worst == .none && status != "UP" && !status.isEmpty {
                worst = status.contains("MAINTEN") ? .minor : .major
            }

            // Active incidents/maintenances are already only the unresolved
            // ones in Instatus' summary feed — the newest is listed first.
            let incidentTitle = incidents.first?.name ?? maintenances.first?.name
            let description = incidentTitle ?? worst.defaultDescription
            return result(service, worst, description, incidentTitle: incidentTitle)
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    private static func indicator(impact: String?) -> Indicator {
        switch (impact ?? "").uppercased() {
        case "MAJOROUTAGE": return .critical
        case "PARTIALOUTAGE": return .major
        case "MINOROUTAGE", "DEGRADEDPERFORMANCE": return .minor
        case "OPERATIONAL", "": return .none
        default: return .major
        }
    }

    /// Normalizes a page URL to its `/summary.json` endpoint on the same host.
    static func summaryEndpoint(for url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host != nil else { return nil }
        components.scheme = "https"
        components.path = "/summary.json"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
