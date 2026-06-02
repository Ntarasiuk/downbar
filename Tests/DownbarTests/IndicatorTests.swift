import XCTest
@testable import Downbar

/// Mapping and ordering guarantees for `Indicator`, plus the aggregate
/// "worst wins, but unknown never masks" rule that the menu-bar icon depends on.
final class IndicatorTests: XCTestCase {

    // MARK: - Statuspage string mapping

    func testStatuspageIndicatorMapping() {
        XCTAssertEqual(Indicator(statuspageIndicator: "none"), .none)
        XCTAssertEqual(Indicator(statuspageIndicator: "minor"), .minor)
        XCTAssertEqual(Indicator(statuspageIndicator: "maintenance"), .minor)
        XCTAssertEqual(Indicator(statuspageIndicator: "major"), .major)
        XCTAssertEqual(Indicator(statuspageIndicator: "critical"), .critical)
    }

    func testStatuspageIndicatorIsCaseInsensitive() {
        XCTAssertEqual(Indicator(statuspageIndicator: "NONE"), .none)
        XCTAssertEqual(Indicator(statuspageIndicator: "Major"), .major)
    }

    func testStatuspageIndicatorUnrecognizedIsUnknown() {
        XCTAssertEqual(Indicator(statuspageIndicator: ""), .unknown)
        XCTAssertEqual(Indicator(statuspageIndicator: "bogus"), .unknown)
    }

    // MARK: - Comparable ordering

    func testComparableSeverityOrdering() {
        XCTAssertLessThan(Indicator.unknown, .none)
        XCTAssertLessThan(Indicator.none, .minor)
        XCTAssertLessThan(Indicator.minor, .major)
        XCTAssertLessThan(Indicator.major, .critical)
    }

    func testMaxYieldsWorstIndicator() {
        XCTAssertEqual([Indicator.none, .minor, .major].max(), .major)
        XCTAssertEqual([Indicator.none, Indicator.none].max(), Indicator.none)
    }

    func testRawValuesMatchSeverityOrder() {
        XCTAssertEqual(Indicator.unknown.rawValue, -1)
        XCTAssertEqual(Indicator.none.rawValue, 0)
        XCTAssertEqual(Indicator.critical.rawValue, 3)
    }

    // MARK: - Aggregate semantics
    //
    // `StatusMonitor.aggregate` computes `real.max()` where `real` drops any
    // `.unknown` reading, falling back to `.unknown` only when *every* reading
    // is unknown. These tests pin that exact rule on the same `Indicator`
    // primitives the monitor uses.

    /// Replicates `StatusMonitor.aggregate`'s pure core over a set of readings.
    private func aggregate(_ readings: [Indicator]) -> Indicator {
        guard !readings.isEmpty else { return .unknown }
        let real = readings.filter { $0 != .unknown }
        return real.max() ?? .unknown
    }

    func testAggregateUnknownDoesNotMaskOutage() {
        // A single unreachable service must not hide a real outage elsewhere.
        XCTAssertEqual(aggregate([.unknown, .critical, .none]), .critical)
        XCTAssertEqual(aggregate([.none, .unknown, .minor]), .minor)
    }

    func testAggregateAllUnknownIsUnknown() {
        XCTAssertEqual(aggregate([.unknown, .unknown]), .unknown)
    }

    func testAggregateAllOperationalIsNone() {
        XCTAssertEqual(aggregate([.none, .none, .none]), .none)
    }

    func testAggregateEmptyIsUnknown() {
        XCTAssertEqual(aggregate([]), .unknown)
    }
}
