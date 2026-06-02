import Foundation

/// Generic uptime check for any website or server: performs an HTTP request to
/// the URL and reports health from the response (or lack of one). Unlike the
/// status-page adapters, an unreachable host here means the thing is genuinely
/// **down** (red/critical), not "unknown" — that's the point of the check.
struct WebsiteProvider: StatusProvider {
    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = WebsiteProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        var request = URLRequest(url: service.url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh) Downbar/1.0", forHTTPHeaderField: "User-Agent")

        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else {
                return result(service, .none, "Online · \(ms) ms")
            }
            let (indicator, label) = Self.classify(http.statusCode)
            return result(service, indicator, "\(label) · HTTP \(http.statusCode) · \(ms) ms")
        } catch {
            // No response at all → down.
            return ServiceStatusResult(
                serviceID: service.id,
                indicator: .critical,
                description: "Offline · \(Self.errorText(error))",
                lastChecked: Date()
            )
        }
    }

    private static func classify(_ code: Int) -> (Indicator, String) {
        switch code {
        case 200..<400: return (.none, "Online")
        case 401, 403: return (.minor, "Restricted")     // reachable but gated
        case 429: return (.minor, "Rate limited")
        case 400..<500: return (.major, "Client error")
        case 500..<600: return (.critical, "Server error")
        default: return (.major, "Unexpected")
        }
    }

    private static func errorText(_ error: Error) -> String {
        guard let url = error as? URLError else { return error.localizedDescription }
        switch url.code {
        case .timedOut: return "Timed out"
        case .cannotFindHost: return "Host not found"
        case .cannotConnectToHost: return "Connection refused"
        case .notConnectedToInternet: return "No internet"
        case .networkConnectionLost: return "Connection lost"
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid:
            return "TLS error"
        case .dnsLookupFailed: return "DNS lookup failed"
        default: return url.localizedDescription
        }
    }
}
