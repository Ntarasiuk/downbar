import Foundation

/// Reads xAI's status feed (a custom Next.js status page, not Statuspage or
/// Instatus):
///   GET https://status.x.ai/feed.xml
/// It's a standard RSS 2.0 *history* feed — every `<item>` is an incident whose
/// `<description>` CDATA carries `Status: <STATE>` and `Severity: <level>`, plus
/// a `<pubDate>`. Because resolved incidents stay in the feed, an incident
/// counts as *current* only when its status is not terminal (RESOLVED /
/// COMPLETED) **and** its latest update is recent — the recency guard stops a
/// stale, never-closed item from reading as a permanent outage.
///
/// Note: at build time the live feed contained only resolved incidents, so the
/// active-state vocabulary couldn't be observed. The parser is deliberately
/// permissive — anything not clearly terminal is treated as active, and an
/// active incident defaults to at least `.minor` so a real outage is never
/// silently dropped, with the title/severity escalating it when they say so.
struct XAIProvider: StatusProvider {
    private static let feed = URL(string: "https://status.x.ai/feed.xml")!

    /// A non-resolved incident whose newest update is older than this is treated
    /// as stale (the feed likely just never recorded its closure) and ignored.
    private static let activeWindow: TimeInterval = 3 * 24 * 60 * 60

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = XAIProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        do {
            let (data, response) = try await session.data(from: Self.feed)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            guard let xml = String(data: data, encoding: .utf8) else {
                return unknown(service, "Decode error")
            }

            let active = Self.activeIncidents(in: xml, now: Date())
            guard let worst = active.map(\.indicator).max() else {
                return result(service, .none, "All Systems Operational")
            }
            // Lead with the worst incident's title.
            let lead = active.first { $0.indicator == worst } ?? active[0]
            let more = active.count > 1 ? " (+\(active.count - 1) more)" : ""
            return result(service, worst, "\(lead.title)\(more)",
                          incidentTitle: lead.title, isMaintenance: lead.isMaintenance)
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    // MARK: - Parsing

    struct Incident {
        let title: String
        let indicator: Indicator
        let isMaintenance: Bool
    }

    /// Currently-active incidents: not terminal and updated within `activeWindow`.
    static func activeIncidents(in xml: String, now: Date) -> [Incident] {
        items(in: xml).compactMap { item -> Incident? in
            let descr = tagText("description", in: item) ?? ""
            let state = field("Status", in: descr).uppercased()
            // Terminal states are done; anything else is treated as ongoing.
            if state.contains("RESOLVED") || state.contains("COMPLETED") || state.contains("POSTMORTEM") {
                return nil
            }
            // Recency guard against a never-closed historical item.
            if let date = pubDate(in: item), now.timeIntervalSince(date) > activeWindow {
                return nil
            }
            let title = tagText("title", in: item) ?? "Active incident"
            let severity = field("Severity", in: descr)
            let isMaintenance = state.contains("MAINTENANCE") || severity.lowercased().contains("maintenance")
            return Incident(title: title,
                            indicator: indicator(severity: severity, title: title),
                            isMaintenance: isMaintenance)
        }
    }

    /// Maps an incident's severity + title onto our scale. The severity field is
    /// authoritative when it names an outage level; the title escalates it; an
    /// otherwise-unclassified active incident is `.minor` (never dropped).
    static func indicator(severity: String, title: String) -> Indicator {
        let s = (severity + " " + title).lowercased()
        if s.contains("major outage") || s.contains("critical") || s.contains("unavailable") || s.contains("down") {
            return .critical
        }
        if s.contains("outage") || s.contains("partial") {
            return .major
        }
        if s.contains("maintenance") { return .minor }
        // degraded, increased errors, elevated latency, disruption, minor, …
        return .minor
    }

    // MARK: - Tiny XML helpers (same approach as AzureProvider)

    /// Each `<item>…</item>` block.
    private static func items(in xml: String) -> [String] {
        var out: [String] = []
        var search = xml[...]
        while let open = search.range(of: "<item"),
              let close = search.range(of: "</item>", range: open.upperBound..<search.endIndex) {
            out.append(String(search[open.upperBound..<close.lowerBound]))
            search = search[close.upperBound...]
        }
        return out
    }

    /// First `<tag>…</tag>` text, stripping a CDATA wrapper if present.
    private static func tagText(_ tag: String, in xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>") ?? xml.range(of: "<\(tag) "),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        // Skip to the end of the opening tag when it had attributes.
        let bodyStart = xml.range(of: ">", range: open.lowerBound..<close.lowerBound)?.upperBound ?? open.upperBound
        var text = String(xml[bodyStart..<close.lowerBound])
        text = text.replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Reads a `Label: value` line out of the (HTML) description CDATA, ignoring
    /// surrounding tags — e.g. `<h3>Status: RESOLVED</h3>` → "RESOLVED".
    private static func field(_ label: String, in description: String) -> String {
        guard let r = description.range(of: "\(label):") else { return "" }
        let tail = description[r.upperBound...]
        // Value runs until the next tag (<…) or line break.
        let value = tail.prefix { $0 != "<" && $0 != "\n" && $0 != "\r" }
        return value.trimmingCharacters(in: .whitespaces)
    }

    private static let rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    private static func pubDate(in item: String) -> Date? {
        guard let raw = tagText("pubDate", in: item) else { return nil }
        return rfc822.date(from: raw)
    }
}
