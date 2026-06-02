import Foundation

/// Reads the uniform Statuspage.io endpoint:
///   GET https://<host>/api/v2/status.json
///   → { "status": { "indicator": "none|minor|major|critical",
///                   "description": "All Systems Operational" } }
/// Covers GitHub, Cloudflare, Vercel, OpenAI, Stripe (stripestatus.com),
/// Anthropic (status.claude.com), and hundreds more.
struct StatuspageProvider: StatusProvider {
    private struct Payload: Decodable {
        struct Status: Decodable {
            let indicator: String
            let description: String
        }
        struct Incident: Decodable {
            let name: String?
            let status: String?
        }
        let status: Status
        // Present on `/api/v2/summary.json`; absent on `status.json` → nil.
        let incidents: [Incident]?
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = StatuspageProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        guard let endpoint = StatuspageProvider.statusEndpoint(for: service.url) else {
            return unknown(service, "Invalid URL")
        }
        do {
            let (data, response) = try await session.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return unknown(service, "HTTP \(code)")
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return result(service,
                          Indicator(statuspageIndicator: payload.status.indicator),
                          payload.status.description,
                          incidentTitle: Self.activeIncidentName(payload.incidents))
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    /// Name of the most recent unresolved incident, if any. Statuspage marks a
    /// finished incident with status "resolved" or "postmortem".
    private static func activeIncidentName(_ incidents: [Payload.Incident]?) -> String? {
        incidents?.first { incident in
            let status = (incident.status ?? "").lowercased()
            return status != "resolved" && status != "postmortem"
        }?.name
    }

    /// Normalizes any page URL to its `/api/v2/status.json` endpoint on the same host.
    static func statusEndpoint(for url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host != nil else { return nil }
        components.scheme = "https"
        components.path = "/api/v2/status.json"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
