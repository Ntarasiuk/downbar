import SwiftUI

/// Normalized health level, shared across every provider format.
/// Ordered by severity so `max(...)` yields the worst indicator for the
/// aggregate menu-bar icon. `.unknown` sits below real states so that a single
/// unreachable service does not mask a genuine outage elsewhere.
enum Indicator: Int, Codable, Comparable, CaseIterable {
    case unknown = -1   // fetch/parse failure — gray
    case none = 0       // all operational — green
    case minor = 1      // degraded — yellow
    case major = 2      // partial outage — orange
    case critical = 3   // major outage — red

    static func < (lhs: Indicator, rhs: Indicator) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Maps Statuspage.io's `status.indicator` string onto our enum.
    init(statuspageIndicator raw: String) {
        switch raw.lowercased() {
        case "none": self = .none
        case "minor", "maintenance": self = .minor
        case "major": self = .major
        case "critical": self = .critical
        default: self = .unknown
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .minor: return "exclamationmark.triangle.fill"
        case .major: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .none: return .green
        case .minor: return .yellow
        case .major: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    /// Default human label when a provider doesn't supply its own description.
    var defaultDescription: String {
        switch self {
        case .none: return "All Systems Operational"
        case .minor: return "Degraded Performance"
        case .major: return "Partial Outage"
        case .critical: return "Major Outage"
        case .unknown: return "Unreachable"
        }
    }
}

/// The result of fetching one service's status at a point in time.
struct ServiceStatusResult: Identifiable {
    let serviceID: UUID
    let indicator: Indicator
    let description: String
    let lastChecked: Date
    /// Name of the most recent active/unresolved incident, when one is in
    /// progress. More specific than `description`; nil when all clear.
    var incidentTitle: String? = nil

    var id: UUID { serviceID }
}
