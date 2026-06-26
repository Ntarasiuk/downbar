import Foundation

/// One status-page format = one conforming type, all behind the same
/// `Indicator` model. A provider must never throw: any error becomes a
/// `.unknown` result carrying the error text, so a flaky network or a
/// format change can't crash the UI.
protocol StatusProvider {
    func fetch(_ service: Service) async -> ServiceStatusResult
}

extension StatusProvider {
    /// Builds a fresh ~10s-timeout ephemeral session. Each provider stores its
    /// own (injectable) instance so tests can swap in a mock `URLSession`.
    static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    func unknown(_ service: Service, _ message: String) -> ServiceStatusResult {
        ServiceStatusResult(
            serviceID: service.id,
            indicator: .unknown,
            description: message,
            lastChecked: Date()
        )
    }

    func result(_ service: Service, _ indicator: Indicator, _ description: String, incidentTitle: String? = nil, isMaintenance: Bool = false) -> ServiceStatusResult {
        ServiceStatusResult(
            serviceID: service.id,
            indicator: indicator,
            description: description.isEmpty ? indicator.defaultDescription : description,
            lastChecked: Date(),
            incidentTitle: incidentTitle,
            isMaintenance: isMaintenance
        )
    }
}

/// Resolves a `ProviderKind` to its adapter.
enum ProviderRegistry {
    static func provider(for kind: ProviderKind) -> StatusProvider {
        switch kind {
        case .statuspage: return StatuspageProvider()
        case .instatus: return InstatusProvider()
        case .website: return WebsiteProvider()
        case .aws: return AWSProvider()
        case .apple: return AppleProvider()
        case .gcp: return GCPProvider()
        case .azure: return AzureProvider()
        case .xai: return XAIProvider()
        case .statusio: return StatusIOProvider()
        }
    }
}
