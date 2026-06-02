import XCTest
@testable import Downbar

/// Drives every provider against saved fixture payloads through an injected
/// mock `URLSession`, asserting the `Indicator` (and where relevant the parsed
/// incident title) each canned response produces.
final class ProviderFixtureTests: XCTestCase {
    private func service(_ urlString: String, _ kind: ProviderKind) -> Service {
        Service(name: "Test", url: URL(string: urlString)!, provider: kind)
    }

    // MARK: - Statuspage

    func testStatuspageAllOperational() async {
        MockURLProtocol.respond("""
        { "status": { "indicator": "none", "description": "All Systems Operational" } }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://www.githubstatus.com", .statuspage))
        XCTAssertEqual(r.indicator, .none)
        XCTAssertEqual(r.description, "All Systems Operational")
        XCTAssertNil(r.incidentTitle)
    }

    func testStatuspageActiveIncidentParsesTitle() async {
        // `summary.json`-shaped payload: a `minor` indicator plus an unresolved
        // incident whose name must surface as `incidentTitle`.
        MockURLProtocol.respond("""
        {
          "status": { "indicator": "minor", "description": "Degraded Performance" },
          "incidents": [
            { "name": "Elevated API error rates", "status": "investigating" },
            { "name": "Old thing", "status": "resolved" }
          ]
        }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.openai.com", .statuspage))
        XCTAssertEqual(r.indicator, .minor)
        XCTAssertEqual(r.incidentTitle, "Elevated API error rates")
    }

    func testStatuspageMaintenanceIsMinorAndFlagged() async {
        // Statuspage's `maintenance` indicator maps to `.minor` (planned work,
        // not an outage) but must set `isMaintenance` so the row reads calmly.
        MockURLProtocol.respond("""
        { "status": { "indicator": "maintenance", "description": "Scheduled Maintenance" } }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.example.com", .statuspage))
        XCTAssertEqual(r.indicator, .minor)
        XCTAssertTrue(r.isMaintenance)
    }

    func testStatuspageNonMaintenanceIsNotFlagged() async {
        MockURLProtocol.respond("""
        { "status": { "indicator": "minor", "description": "Degraded Performance" } }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.example.com", .statuspage))
        XCTAssertFalse(r.isMaintenance)
    }

    func testStatuspageMajorIndicator() async {
        MockURLProtocol.respond("""
        { "status": { "indicator": "major", "description": "Partial Outage" } }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.example.com", .statuspage))
        XCTAssertEqual(r.indicator, .major)
    }

    func testStatuspageResolvedIncidentYieldsNoTitle() async {
        MockURLProtocol.respond("""
        {
          "status": { "indicator": "none", "description": "All Systems Operational" },
          "incidents": [ { "name": "Yesterday", "status": "resolved" } ]
        }
        """)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.example.com", .statuspage))
        XCTAssertEqual(r.indicator, .none)
        XCTAssertNil(r.incidentTitle)
    }

    func testStatuspageHTTPErrorIsUnknown() async {
        MockURLProtocol.respond("nope", status: 503)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.example.com", .statuspage))
        XCTAssertEqual(r.indicator, .unknown)
    }

    func testStatuspageEndpointNormalization() {
        let endpoint = StatuspageProvider.statusEndpoint(
            for: URL(string: "https://www.githubstatus.com/some/page?x=1#frag")!)
        XCTAssertEqual(endpoint?.absoluteString, "https://www.githubstatus.com/api/v2/status.json")
    }

    // MARK: - Instatus

    func testInstatusOperational() async {
        MockURLProtocol.respond("""
        { "page": { "status": "UP" }, "activeIncidents": [], "activeMaintenances": [] }
        """)
        let provider = InstatusProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://xai.instatus.com", .instatus))
        XCTAssertEqual(r.indicator, .none)
        XCTAssertNil(r.incidentTitle)
    }

    func testInstatusActiveIncidentMapsImpact() async {
        MockURLProtocol.respond("""
        {
          "page": { "status": "HASISSUES" },
          "activeIncidents": [ { "name": "Search slow", "impact": "PARTIALOUTAGE" } ],
          "activeMaintenances": []
        }
        """)
        let provider = InstatusProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.perplexity.com", .instatus))
        XCTAssertEqual(r.indicator, .major)              // PARTIALOUTAGE → major
        XCTAssertEqual(r.incidentTitle, "Search slow")
    }

    func testInstatusMaintenanceOnlyIsMinor() async {
        MockURLProtocol.respond("""
        {
          "page": { "status": "UNDERMAINTENANCE" },
          "activeIncidents": [],
          "activeMaintenances": [ { "name": "DB upgrade", "impact": null } ]
        }
        """)
        let provider = InstatusProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.recraft.ai", .instatus))
        XCTAssertEqual(r.indicator, .minor)
        XCTAssertEqual(r.incidentTitle, "DB upgrade")
    }

    func testInstatusMajorOutageIsCritical() async {
        MockURLProtocol.respond("""
        {
          "page": { "status": "HASISSUES" },
          "activeIncidents": [ { "name": "Total outage", "impact": "MAJOROUTAGE" } ]
        }
        """)
        let provider = InstatusProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.perplexity.com", .instatus))
        XCTAssertEqual(r.indicator, .critical)
    }

    // MARK: - AWS (UTF-16 BOM-prefixed JSON array)

    /// AWS bodies arrive UTF-16 encoded; encode the fixture the same way so the
    /// provider's `String(data:encoding:.utf16)` round-trip is exercised.
    private func utf16(_ json: String) -> Data {
        json.data(using: .utf16)!
    }

    func testAWSEmptyArrayIsOperational() async {
        MockURLProtocol.respond(utf16("[]"))
        let provider = AWSProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://health.aws.amazon.com/health/status", .aws))
        XCTAssertEqual(r.indicator, .none)
    }

    func testAWSDisruptionIsCritical() async {
        // status "3" == disruption → critical. Global (no ARN region) so it
        // counts regardless of region filter.
        MockURLProtocol.respond(utf16("""
        [ { "status": "3", "summary": "EC2 API errors", "service_name": "EC2", "region_name": "us-east-1" } ]
        """))
        let provider = AWSProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://health.aws.amazon.com/health/status", .aws))
        XCTAssertEqual(r.indicator, .critical)
        XCTAssertTrue(r.description.contains("EC2 API errors"))
    }

    func testAWSResolvedEventIsOperational() async {
        MockURLProtocol.respond(utf16("""
        [ { "status": "0", "summary": "Resolved", "service_name": "S3", "region_name": "us-west-2" } ]
        """))
        let provider = AWSProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://health.aws.amazon.com/health/status", .aws))
        XCTAssertEqual(r.indicator, .none)
    }

    // MARK: - Apple (JSONP wrapper)

    func testAppleOperational() async {
        MockURLProtocol.respond(#"""
        jsonCallback({ "services": [ { "serviceName": "Xcode", "events": [] } ] })
        """#)
        let provider = AppleProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://developer.apple.com/system-status/", .apple))
        XCTAssertEqual(r.indicator, .none)
    }

    func testAppleOutageIsMajor() async {
        MockURLProtocol.respond(#"""
        jsonCallback({ "services": [
          { "serviceName": "APNs", "events": [ { "eventStatus": "Ongoing Outage", "messageType": null, "statusType": null } ] }
        ] })
        """#)
        let provider = AppleProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://developer.apple.com/system-status/", .apple))
        XCTAssertEqual(r.indicator, .major)
        XCTAssertTrue(r.description.contains("APNs"))
    }

    func testAppleIssueIsMinor() async {
        MockURLProtocol.respond(#"""
        jsonCallback({ "services": [
          { "serviceName": "TestFlight", "events": [ { "eventStatus": "Issue", "messageType": null, "statusType": null } ] }
        ] })
        """#)
        let provider = AppleProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://developer.apple.com/system-status/", .apple))
        XCTAssertEqual(r.indicator, .minor)
    }

    // MARK: - GCP (incidents.json, active = no `end`)

    func testGCPNoActiveIncidents() async {
        MockURLProtocol.respond("""
        [ { "end": "2026-01-01T00:00:00Z", "external_desc": "Old", "status_impact": "SERVICE_OUTAGE" } ]
        """)
        let provider = GCPProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.cloud.google.com", .gcp))
        XCTAssertEqual(r.indicator, .none)
    }

    func testGCPActiveOutageIsCritical() async {
        MockURLProtocol.respond("""
        [ { "end": null, "external_desc": "Compute Engine down", "status_impact": "SERVICE_OUTAGE",
            "affected_products": [ { "title": "Compute Engine" } ] } ]
        """)
        let provider = GCPProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.cloud.google.com", .gcp))
        XCTAssertEqual(r.indicator, .critical)
        XCTAssertTrue(r.description.contains("Compute Engine"))
    }

    func testGCPDisruptionIsMajor() async {
        MockURLProtocol.respond("""
        [ { "end": null, "external_desc": "Latency", "status_impact": "SERVICE_DISRUPTION" } ]
        """)
        let provider = GCPProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.cloud.google.com", .gcp))
        XCTAssertEqual(r.indicator, .major)
    }

    // MARK: - Azure (active-only RSS feed)

    func testAzureEmptyFeedIsOperational() async {
        MockURLProtocol.respond("""
        <?xml version="1.0"?><rss><channel></channel></rss>
        """)
        let provider = AzureProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://azure.status.microsoft", .azure))
        XCTAssertEqual(r.indicator, .none)
    }

    func testAzureOutageTitleIsCritical() async {
        MockURLProtocol.respond("""
        <?xml version="1.0"?><rss><channel>
          <item><title><![CDATA[Storage outage in East US]]></title></item>
        </channel></rss>
        """)
        let provider = AzureProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://azure.status.microsoft", .azure))
        XCTAssertEqual(r.indicator, .critical)
        XCTAssertTrue(r.description.contains("Storage outage"))
    }

    func testAzureAdvisoryIsMinor() async {
        MockURLProtocol.respond("""
        <?xml version="1.0"?><rss><channel>
          <item><title>Service advisory for SQL</title></item>
        </channel></rss>
        """)
        let provider = AzureProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://azure.status.microsoft", .azure))
        XCTAssertEqual(r.indicator, .minor)
    }

    // MARK: - Website (HTTP status classification)

    func testWebsiteOnlineIsNone() async {
        MockURLProtocol.respond("<html>ok</html>", status: 200)
        let provider = WebsiteProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://example.com", .website))
        XCTAssertEqual(r.indicator, .none)
        XCTAssertTrue(r.description.contains("HTTP 200"))
    }

    func testWebsiteServerErrorIsCritical() async {
        MockURLProtocol.respond("boom", status: 500)
        let provider = WebsiteProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://example.com", .website))
        XCTAssertEqual(r.indicator, .critical)
    }

    func testWebsiteForbiddenIsMinor() async {
        MockURLProtocol.respond("denied", status: 403)
        let provider = WebsiteProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://example.com", .website))
        XCTAssertEqual(r.indicator, .minor)
    }

    func testWebsiteClientErrorIsMajor() async {
        MockURLProtocol.respond("nope", status: 404)
        let provider = WebsiteProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://example.com", .website))
        XCTAssertEqual(r.indicator, .major)
    }
}
