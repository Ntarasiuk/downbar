import Foundation

/// Reads the uniform Statuspage.io endpoint:
///   GET https://<host>/api/v2/status.json
///   → { "status": { "indicator": "none|minor|major|critical",
///                   "description": "All Systems Operational" } }
/// Covers GitHub, Cloudflare, Vercel, OpenAI, Stripe (stripestatus.com),
/// Anthropic (status.claude.com), and hundreds more.
///
/// When the service has `components` selected, reads `/api/v2/summary.json`
/// instead and reports only those components (e.g. one Cloudflare data center
/// out of hundreds), ignoring the page-wide indicator.
struct StatuspageProvider: StatusProvider {
    struct Component: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let status: String
        /// True for a group header (e.g. Cloudflare's "North America").
        let group: Bool?
        /// The group this component belongs to, if any.
        let groupID: String?

        private enum CodingKeys: String, CodingKey {
            case id, name, status, group, groupID = "group_id"
        }

        /// Maps a component status onto our enum.
        var indicator: Indicator {
            switch status {
            case "operational": return .none
            case "degraded_performance", "under_maintenance": return .minor
            case "partial_outage": return .major
            case "major_outage": return .critical
            default: return .unknown
            }
        }
    }

    private struct Payload: Decodable {
        struct Status: Decodable {
            let indicator: String
            let description: String
        }
        struct Incident: Decodable {
            struct Ref: Decodable { let id: String }
            let name: String?
            let status: String?
            let components: [Ref]?
        }
        let status: Status
        // Present on `/api/v2/summary.json`; absent on `status.json` → nil.
        let incidents: [Incident]?
        let components: [Component]?
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = StatuspageProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        let selected = Set(service.components ?? [])
        let path = selected.isEmpty ? "/api/v2/status.json" : "/api/v2/summary.json"
        guard let endpoint = StatuspageProvider.statusEndpoint(for: service.url, path: path) else {
            return unknown(service, "Invalid URL")
        }
        do {
            let (data, response) = try await session.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return unknown(service, "HTTP \(code)")
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            if !selected.isEmpty {
                return componentResult(service, payload, selected)
            }
            // Statuspage reports an active maintenance window via the
            // `maintenance` indicator (mapped to `.minor`); flag it so the row
            // reads as planned work rather than an outage.
            let isMaintenance = payload.status.indicator.lowercased() == "maintenance"
            return result(service,
                          Indicator(statuspageIndicator: payload.status.indicator),
                          payload.status.description,
                          incidentTitle: Self.activeIncidentName(payload.incidents),
                          isMaintenance: isMaintenance)
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    /// Worst status among the selected components; the description names the
    /// worst one so the row says *where* the problem is.
    private func componentResult(_ service: Service, _ payload: Payload, _ selected: Set<String>) -> ServiceStatusResult {
        // Components we can actually rank. A selected ID that left the page, or
        // a status we don't recognize, is unaccounted for.
        let known = (payload.components ?? []).filter { selected.contains($0.id) && $0.indicator != .unknown }
        guard let worst = known.max(by: { $0.indicator < $1.indicator }) else {
            return unknown(service, "Selected components not found")
        }
        let indicator = worst.indicator
        // A real problem on a known component still wins. But "operational"
        // would be a lie while some watched components can't be read.
        let unaccounted = selected.count - known.count
        if indicator == .none && unaccounted > 0 {
            return unknown(service, "\(unaccounted) of \(selected.count) selected components not found")
        }
        let description = indicator == .none
            ? Indicator.none.defaultDescription
            : "\(worst.name): \(indicator.defaultDescription)"
        let incidents = payload.incidents?.filter {
            $0.components?.contains { selected.contains($0.id) } ?? false
        }
        return result(service, indicator, description,
                      incidentTitle: Self.activeIncidentName(incidents),
                      isMaintenance: worst.status == "under_maintenance")
    }

    /// Every component on the page, for the Settings picker.
    static func fetchComponents(_ pageURL: URL, session: URLSession = makeDefaultSession()) async throws -> [Component] {
        guard let endpoint = statusEndpoint(for: pageURL, path: "/api/v2/summary.json") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(from: endpoint)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        return try JSONDecoder().decode(Payload.self, from: data).components ?? []
    }

    /// Name of the most recent unresolved incident, if any. Statuspage marks a
    /// finished incident with status "resolved" or "postmortem".
    private static func activeIncidentName(_ incidents: [Payload.Incident]?) -> String? {
        incidents?.first { incident in
            let status = (incident.status ?? "").lowercased()
            return status != "resolved" && status != "postmortem"
        }?.name
    }

    /// Normalizes any page URL to an API endpoint (`/api/v2/status.json` by
    /// default) on the same host.
    static func statusEndpoint(for url: URL, path: String = "/api/v2/status.json") -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host != nil else { return nil }
        components.scheme = "https"
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
