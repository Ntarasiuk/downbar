import Foundation

/// Reads Apple's developer system-status feed:
///   GET https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js
/// The body is JSONP: `jsonCallback({ "services": [ { serviceName, events: [...] } ] })`.
/// We strip the wrapper and treat any service with a non-empty `events` array
/// as currently affected. Severity is inferred from the event's `eventStatus`
/// / `messageType` (Apple uses "Resolved", "Issue", "Maintenance", …).
struct AppleProvider: StatusProvider {
    private static let feed = URL(string: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js")!

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
            let (data, response) = try await session.data(from: Self.feed)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            guard let json = Self.stripJSONP(data) else {
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

    /// Strips the `jsonCallback( ... )` wrapper, returning the inner JSON bytes.
    private static func stripJSONP(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8),
              let open = text.firstIndex(of: "("),
              let close = text.lastIndex(of: ")"), open < close else {
            return nil
        }
        let inner = text[text.index(after: open)..<close]
        return inner.data(using: .utf8)
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
