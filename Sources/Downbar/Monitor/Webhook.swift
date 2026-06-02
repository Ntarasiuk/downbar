import Foundation

/// Kind of alert being sent to the webhook.
enum WebhookEvent: String {
    case down
    case recovered
    case test
}

/// Posts alert payloads to a user-configured webhook (Slack, Discord, or any
/// HTTP endpoint). The JSON body carries both a Slack-style `text` and a
/// Discord-style `content` field plus structured keys, so it works out of the
/// box with the common chat services and with custom consumers.
enum Webhook {
    /// The session used for delivery. Injectable so tests can route through a
    /// mock `URLSession` (mirrors the provider pattern).
    nonisolated(unsafe) static var session: URLSession = makeSession()

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }

    /// Fire-and-forget an alert for a real transition.
    static func send(event: WebhookEvent, service: Service, indicator: Indicator, message: String) {
        guard let url = WebhookPrefs.url else { return }
        let payload = makePayload(event: event, name: service.name, page: service.url,
                                  indicator: indicator, message: message)
        Task { await postJSON(payload, to: url) }
    }

    /// Used by the Settings "Send test" button; awaits the result.
    static func sendTest(to url: URL) async -> Bool {
        let payload = makePayload(event: .test, name: "Downbar",
                                  page: URL(string: "https://github.com")!,
                                  indicator: .none, message: "Test alert from Downbar")
        return await postJSON(payload, to: url)
    }

    static func makePayload(event: WebhookEvent, name: String, page: URL,
                            indicator: Indicator, message: String) -> [String: String] {
        let text: String
        switch event {
        case .recovered:
            text = "✅ \(name) recovered — All Systems Operational"
        case .test:
            text = "🔔 Downbar webhook test — alerts are wired up correctly."
        case .down:
            text = "\(emoji(indicator)) \(name) — \(indicator.defaultDescription): \(message)"
        }
        return [
            "text": text,          // Slack
            "content": text,       // Discord
            "event": event.rawValue,
            "service": name,
            "severity": severityName(indicator),
            "description": message,
            "url": page.absoluteString,
        ]
    }

    @discardableResult
    private static func postJSON(_ payload: [String: String], to url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(code)
        } catch {
            return false
        }
    }

    private static func emoji(_ indicator: Indicator) -> String {
        switch indicator {
        case .none: return "✅"
        case .minor: return "⚠️"
        case .major: return "🟠"
        case .critical: return "🔴"
        case .unknown: return "❔"
        }
    }

    private static func severityName(_ indicator: Indicator) -> String {
        switch indicator {
        case .none: return "operational"
        case .minor: return "minor"
        case .major: return "major"
        case .critical: return "critical"
        case .unknown: return "unknown"
        }
    }
}

/// Webhook destination, persisted in UserDefaults. Empty/invalid = disabled.
enum WebhookPrefs {
    private static let urlKey = "webhookURL"

    static var urlString: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    /// Parsed URL, or nil if blank/not an http(s) URL.
    static var url: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.hasPrefix("http") == true,
              url.host != nil else { return nil }
        return url
    }

    static var isConfigured: Bool { url != nil }
}
