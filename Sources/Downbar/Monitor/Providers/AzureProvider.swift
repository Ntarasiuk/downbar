import Foundation

/// Reads Azure's public status RSS feed:
///   GET https://azure.status.microsoft/en-us/status/feed/
/// The feed is *active-only*: each `<item>` is a current incident, and an empty
/// feed means all-clear. Severity is inferred from the item title keywords.
struct AzureProvider: StatusProvider {
    private static let feed = URL(string: "https://azure.status.microsoft/en-us/status/feed/")!

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = AzureProvider.makeDefaultSession()) {
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

            let titles = Self.itemTitles(in: xml)
            guard !titles.isEmpty else {
                return result(service, .none, "All Systems Operational")
            }

            let worst = titles.map(Self.indicator(forTitle:)).max() ?? .major
            let more = titles.count > 1 ? " (+\(titles.count - 1) more)" : ""
            return result(service, worst, "\(titles[0])\(more)")
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    /// Extracts each `<item>`'s `<title>` text (handles CDATA).
    private static func itemTitles(in xml: String) -> [String] {
        var titles: [String] = []
        var search = xml[...]
        while let itemOpen = search.range(of: "<item"),
              let itemClose = search.range(of: "</item>", range: itemOpen.upperBound..<search.endIndex) {
            let item = search[itemOpen.upperBound..<itemClose.lowerBound]
            if let title = firstTagText("title", in: String(item)), !title.isEmpty {
                titles.append(title)
            }
            search = search[itemClose.upperBound...]
        }
        return titles
    }

    private static func firstTagText(_ tag: String, in xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>") ?? xml.range(of: "<\(tag) "),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        var text = String(xml[open.upperBound..<close.lowerBound])
        text = text.replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func indicator(forTitle title: String) -> Indicator {
        let t = title.lowercased()
        if t.contains("outage") { return .critical }
        if t.contains("degrad") || t.contains("disruption") || t.contains("impact") { return .major }
        if t.contains("advisory") || t.contains("information") || t.contains("informational") { return .minor }
        return .major
    }
}
