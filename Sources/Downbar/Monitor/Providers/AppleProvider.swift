import Foundation

/// Reads one of Apple's two system-status feeds. Both expose the same shape —
/// `{ "services": [ { serviceName, events: [...] } ] }` — but in different
/// envelopes: the developer feed is JSONP (`jsonCallback({ ... })`) while the
/// consumer feed is bare JSON. `extractJSON` handles either.
///   • developer (App Store Connect, Xcode Cloud, TestFlight, notarization, …):
///     https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js
///   • consumer (iCloud, App Store, Apple Music, Maps, …):
///     https://www.apple.com/support/systemstatus/data/system_status_en_US.js
/// The feed is chosen from the service's catalog URL host (see `feed(for:)`).
/// Any service with a non-empty `events` array is treated as currently
/// affected. Severity is inferred from the event's `eventStatus` /
/// `messageType` (Apple uses "Resolved", "Issue", "Maintenance", …).
struct AppleProvider: StatusProvider {
    private static let developerFeed = URL(string: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js")!
    private static let consumerFeed = URL(string: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js")!

    /// Picks the developer dashboard for `developer.apple.com` catalog entries,
    /// otherwise the consumer status page.
    private static func feed(for service: Service) -> URL {
        (service.url.host()?.contains("developer.apple.com") == true) ? developerFeed : consumerFeed
    }

    private struct Payload: Decodable {
        let services: [ServiceEntry]
    }
    private struct ServiceEntry: Decodable {
        let serviceName: String
        let events: [Event]
    }
    private struct Event: Decodable {
        let messageType: String?
        let eventStatus: String?
        let statusType: String?
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = AppleProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        do {
            let (data, response) = try await session.data(from: Self.feed(for: service))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            guard let json = Self.extractJSON(data) else {
                return unknown(service, "Unexpected format")
            }
            let payload = try JSONDecoder().decode(Payload.self, from: json)

            // Services with active (non-resolved) events.
            let affected = payload.services.filter { entry in
                entry.events.contains { Self.indicator(for: $0) > .none }
            }
            guard !affected.isEmpty else {
                return result(service, .none, "All Systems Operational")
            }

            let worst = affected
                .flatMap { $0.events.map(Self.indicator(for:)) }
                .max() ?? .minor
            let names = affected.prefix(2).map(\.serviceName).joined(separator: ", ")
            let more = affected.count > 2 ? " (+\(affected.count - 2) more)" : ""
            return result(service, worst, "\(names)\(more)")
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    /// Returns the JSON object bytes from either feed: bare JSON is passed
    /// through, and a JSONP wrapper (`callback({ ... });`) is unwrapped by
    /// slicing from the first `{` to the last `}`. Slicing on braces rather than
    /// the callback's parens is robust to parens inside event message text.
    private static func extractJSON(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8),
              let open = text.firstIndex(of: "{"),
              let close = text.lastIndex(of: "}"), open < close else {
            return nil
        }
        return text[open...close].data(using: .utf8)
    }

    private static func indicator(for event: Event) -> Indicator {
        let type = (event.eventStatus ?? event.messageType ?? event.statusType ?? "").lowercased()
        if type.contains("resolved") || type.contains("completed") || type.isEmpty {
            return .none
        }
        if type.contains("outage") {
            return .major
        }
        // "issue", "maintenance", "degraded", anything else ongoing.
        return .minor
    }
}
