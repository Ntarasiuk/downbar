import Foundation

/// Reads a [Status.io](https://status.io)-powered status page (e.g. GitLab,
/// Docker Hub). Status.io serves its live summary from
///   GET https://api.status.io/1.0/status/<pageId>
/// where `<pageId>` is embedded in the human page's HTML as `pageId = '...'`.
/// We scrape that id from the catalog URL's page, then read the JSON summary —
/// so a single provider works for any Status.io page without hardcoding ids.
struct StatusIOProvider: StatusProvider {
    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = StatusIOProvider.makeDefaultSession()) {
        self.session = session
    }

    private struct Payload: Decodable {
        struct Result: Decodable {
            struct Overall: Decodable {
                let status: String?
                let status_code: Int?
            }
            let status_overall: Overall?
        }
        let result: Result?
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        do {
            // 1. Scrape the page id from the human status page.
            let (pageData, pageResp) = try await session.data(from: service.url)
            guard let pageHTTP = pageResp as? HTTPURLResponse, (200..<300).contains(pageHTTP.statusCode) else {
                return unknown(service, "HTTP \((pageResp as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            guard let html = String(data: pageData, encoding: .utf8),
                  let pageId = Self.pageId(in: html),
                  let api = URL(string: "https://api.status.io/1.0/status/\(pageId)") else {
                return unknown(service, "Couldn't find a Status.io page id")
            }

            // 2. Read the live summary.
            let (data, response) = try await session.data(from: api)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard let overall = payload.result?.status_overall else {
                return unknown(service, "Unexpected format")
            }
            let indicator = Self.indicator(code: overall.status_code, status: overall.status)
            return result(service, indicator, overall.status ?? indicator.defaultDescription)
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    /// Extracts the `pageId = '...'` value embedded in a Status.io page.
    static func pageId(in html: String) -> String? {
        guard let label = html.range(of: "pageId") else { return nil }
        let tail = html[label.upperBound...]
        guard let q1 = tail.firstIndex(where: { $0 == "'" || $0 == "\"" }) else { return nil }
        let body = tail[tail.index(after: q1)...]
        guard let q2 = body.firstIndex(where: { $0 == "'" || $0 == "\"" }) else { return nil }
        let id = body[..<q2].trimmingCharacters(in: .whitespaces)
        // Status.io ids are hex; reject anything else so a stray match fails safe.
        let isHex = !id.isEmpty && id.allSatisfy { $0.isHexDigit }
        return isHex ? id : nil
    }

    /// Maps Status.io's `status_overall.status_code` onto our scale:
    /// 100 Operational · 200 Degraded Performance · 300 Partial Service
    /// Disruption · 400 Service Disruption · 500 Security Event. Falls back to
    /// the status text when the code is missing/unexpected.
    static func indicator(code: Int?, status: String?) -> Indicator {
        switch code {
        case 100: return .none
        case 200: return .minor
        case 300: return .major
        case 400, 500: return .critical
        default: break
        }
        let s = (status ?? "").lowercased()
        if s.isEmpty { return .unknown }
        if s.contains("operational") { return .none }
        if s.contains("security") || s.contains("disruption") || s.contains("outage") { return .critical }
        if s.contains("degraded") || s.contains("partial") || s.contains("maintenance") { return .minor }
        return .minor
    }
}
