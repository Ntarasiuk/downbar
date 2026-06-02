import Foundation

/// Reads AWS Health's public current-events feed:
///   GET https://health.aws.amazon.com/public/currentevents
/// The body is a **UTF-16-encoded** (BOM-prefixed) JSON array of active events.
/// An empty array means all-clear. Each event carries a `status` string:
///   "0" resolved · "1" informational · "2" degradation · "3" disruption.
/// We aggregate to the worst current status across all events.
///
/// The `service.url` is treated as the public status page to open on click
/// (e.g. https://health.aws.amazon.com/health/status); the feed URL is fixed.
struct AWSProvider: StatusProvider {
    private static let feed = URL(string: "https://health.aws.amazon.com/public/currentevents")!

    private struct Event: Decodable {
        let status: String?
        let summary: String?
        let service_name: String?
        let region_name: String?
        let arn: String?
    }

    /// Injected so tests can supply a mock `URLSession`.
    let session: URLSession

    init(session: URLSession = AWSProvider.makeDefaultSession()) {
        self.session = session
    }

    func fetch(_ service: Service) async -> ServiceStatusResult {
        do {
            var request = URLRequest(url: Self.feed)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return unknown(service, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }

            // Re-decode UTF-16 (BOM-aware) into UTF-8 for JSONDecoder.
            guard let text = String(data: data, encoding: .utf16),
                  let utf8 = text.data(using: .utf8) else {
                return unknown(service, "Decode error")
            }
            let events = try JSONDecoder().decode([Event].self, from: utf8)

            // Scope to the user's regions (empty = all). Global/region-less
            // events (Route 53, IAM, CloudFront, …) always count since they
            // affect every region.
            let filter = AWSRegionFilter.selected
            let active = events
                .filter { Self.indicator(for: $0.status) > .none }
                .filter { event in
                    guard !filter.isEmpty else { return true }
                    let region = Self.region(from: event.arn)
                    return region.isEmpty || filter.contains(region)
                }

            guard let worst = active.map({ Self.indicator(for: $0.status) }).max() else {
                return result(service, .none, "All Systems Operational")
            }

            let lead = active.first { Self.indicator(for: $0.status) == worst }
            let summary = lead?.summary ?? worst.defaultDescription
            let region = lead?.region_name.map { " — \($0)" } ?? ""
            let more = active.count > 1 ? " (+\(active.count - 1) more)" : ""
            return result(service, worst, "\(summary)\(region)\(more)")
        } catch {
            return unknown(service, error.localizedDescription)
        }
    }

    private static func indicator(for status: String?) -> Indicator {
        switch status {
        case "1": return .minor
        case "2": return .major
        case "3": return .critical
        default: return .none   // "0", nil, or unrecognized → resolved/clear
        }
    }

    /// Region code from a Health ARN, e.g.
    /// `arn:aws:health:me-central-1::event/...` → `me-central-1`.
    /// Returns "" for global (region-less) events.
    private static func region(from arn: String?) -> String {
        guard let arn else { return "" }
        let parts = arn.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count > 3 ? String(parts[3]) : ""
    }
}

/// User's AWS region scope, persisted in UserDefaults. Empty = monitor all
/// regions (the default).
enum AWSRegionFilter {
    private static let key = "awsRegions"

    static var selected: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: key) }
    }

    /// A selectable AWS region: code plus a human label.
    struct Region: Hashable {
        let code: String
        let name: String
    }

    /// A geographic grouping of regions, for the Settings picker.
    struct Group: Hashable {
        let title: String
        let regions: [Region]
    }

    /// Regions offered in Settings, grouped by geography.
    static let groups: [Group] = [
        Group(title: "Americas", regions: [
            Region(code: "us-east-1", name: "N. Virginia"),
            Region(code: "us-east-2", name: "Ohio"),
            Region(code: "us-west-1", name: "N. California"),
            Region(code: "us-west-2", name: "Oregon"),
            Region(code: "ca-central-1", name: "Canada"),
            Region(code: "sa-east-1", name: "São Paulo"),
        ]),
        Group(title: "Europe", regions: [
            Region(code: "eu-west-1", name: "Ireland"),
            Region(code: "eu-west-2", name: "London"),
            Region(code: "eu-west-3", name: "Paris"),
            Region(code: "eu-central-1", name: "Frankfurt"),
            Region(code: "eu-central-2", name: "Zurich"),
            Region(code: "eu-north-1", name: "Stockholm"),
            Region(code: "eu-south-1", name: "Milan"),
        ]),
        Group(title: "Asia Pacific", regions: [
            Region(code: "ap-south-1", name: "Mumbai"),
            Region(code: "ap-southeast-1", name: "Singapore"),
            Region(code: "ap-southeast-2", name: "Sydney"),
            Region(code: "ap-northeast-1", name: "Tokyo"),
            Region(code: "ap-northeast-2", name: "Seoul"),
            Region(code: "ap-northeast-3", name: "Osaka"),
            Region(code: "ap-east-1", name: "Hong Kong"),
        ]),
        Group(title: "Middle East & Africa", regions: [
            Region(code: "me-central-1", name: "UAE"),
            Region(code: "me-south-1", name: "Bahrain"),
            Region(code: "af-south-1", name: "Cape Town"),
        ]),
    ]

    /// Flat list of every selectable region code.
    static let common: [String] = groups.flatMap { $0.regions.map(\.code) }
}
