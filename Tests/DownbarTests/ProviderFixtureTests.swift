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

    /// Cloudflare-shaped `summary.json`: the page is in a major outage because
    /// of far-away data centers, but the watched one is fine.
    private static let componentSummary = """
    {
      "status": { "indicator": "major", "description": "Partial System Outage" },
      "components": [
        { "id": "na", "name": "North America", "status": "operational", "group": true },
        { "id": "smf", "name": "Sacramento, CA, United States - (SMF)", "status": "operational", "group_id": "na" },
        { "id": "sjc", "name": "San Jose, CA, United States - (SJC)", "status": "partial_outage", "group_id": "na" },
        { "id": "blr", "name": "Bangalore, India - (BLR)", "status": "major_outage", "group_id": "as" }
      ],
      "incidents": [
        { "name": "Bangalore offline", "status": "investigating", "components": [ { "id": "blr" } ] },
        { "name": "San Jose packet loss", "status": "identified", "components": [ { "id": "sjc" } ] }
      ]
    }
    """

    func testStatuspageComponentFilterIgnoresOtherComponents() async {
        MockURLProtocol.respond(Self.componentSummary)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["smf"]
        let r = await provider.fetch(svc)
        XCTAssertEqual(r.indicator, .none)
        XCTAssertEqual(r.description, "All Systems Operational")
        XCTAssertNil(r.incidentTitle)
    }

    func testStatuspageComponentFilterReportsWorstWatched() async {
        MockURLProtocol.respond(Self.componentSummary)
        let provider = StatuspageProvider(session: MockURLProtocol.makeSession())
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["smf", "sjc"]
        let r = await provider.fetch(svc)
        XCTAssertEqual(r.indicator, .major)
        XCTAssertEqual(r.description, "San Jose, CA, United States - (SJC): Partial Outage")
        XCTAssertEqual(r.incidentTitle, "San Jose packet loss")
    }

    func testStatuspageComponentFilterUsesSummaryEndpoint() async {
        nonisolated(unsafe) var path = ""
        let data = Data(Self.componentSummary.utf8)
        MockURLProtocol.responder = { req in path = req.url?.path ?? ""; return (data, 200) }
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["smf"]
        _ = await StatuspageProvider(session: MockURLProtocol.makeSession()).fetch(svc)
        XCTAssertEqual(path, "/api/v2/summary.json")
    }

    func testStatuspageMissingComponentIsUnknown() async {
        MockURLProtocol.respond(Self.componentSummary)
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["gone"]
        let r = await StatuspageProvider(session: MockURLProtocol.makeSession()).fetch(svc)
        XCTAssertEqual(r.indicator, .unknown)
    }

    func testStatuspagePartlyMissingComponentsAreUnknown() async {
        MockURLProtocol.respond(Self.componentSummary)
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["smf", "gone"]
        let r = await StatuspageProvider(session: MockURLProtocol.makeSession()).fetch(svc)
        XCTAssertEqual(r.indicator, .unknown)
        XCTAssertEqual(r.description, "1 of 2 selected components not found")
    }

    func testStatuspageOutageWinsOverMissingComponent() async {
        MockURLProtocol.respond(Self.componentSummary)
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["sjc", "gone"]
        let r = await StatuspageProvider(session: MockURLProtocol.makeSession()).fetch(svc)
        XCTAssertEqual(r.indicator, .major)
    }

    func testStatuspageUnrecognizedComponentStatusIsNotHidden() async {
        MockURLProtocol.respond("""
        {
          "status": { "indicator": "none", "description": "All Systems Operational" },
          "components": [
            { "id": "a", "name": "A", "status": "operational" },
            { "id": "b", "name": "B", "status": "some_new_status" }
          ]
        }
        """)
        var svc = service("https://www.cloudflarestatus.com", .statuspage)
        svc.components = ["a", "b"]
        let r = await StatuspageProvider(session: MockURLProtocol.makeSession()).fetch(svc)
        XCTAssertEqual(r.indicator, .unknown)
    }

    func testStatuspageFetchComponentsReportsHTTPStatus() async {
        MockURLProtocol.respond("<html>Not Found</html>", status: 404)
        do {
            _ = try await StatuspageProvider.fetchComponents(
                URL(string: "https://www.cloudflarestatus.com")!,
                session: MockURLProtocol.makeSession())
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "HTTP 404")
        }
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

    /// The consumer feed is bare JSON (no `jsonCallback(...)` wrapper); it must
    /// parse just like the JSONP developer feed.
    func testAppleConsumerBareJSON() async {
        MockURLProtocol.respond(#"""
        {"drMessage":null,"services":[
          {"serviceName":"App Store","redirectUrl":null,"events":[]},
          {"serviceName":"iCloud Mail","redirectUrl":null,"events":[{"eventStatus":"Ongoing Issue","messageType":null,"statusType":null}]}
        ],"drpost":false}
        """#)
        let provider = AppleProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://www.apple.com/support/systemstatus/", .apple))
        XCTAssertEqual(r.indicator, .minor)
        XCTAssertTrue(r.description.contains("iCloud Mail"))
    }

    /// The catalog ships two Apple entries that must hit different feeds:
    /// `developer.apple.com` → the developer dashboard, everything else → the
    /// consumer status page. Both feeds share the same JSONP shape.
    func testAppleFeedRoutingByHost() async {
        /// Thread-safe capture for the `@Sendable` mock responder.
        final class Captured: @unchecked Sendable {
            private let lock = NSLock()
            private var value: URL?
            var url: URL? {
                get { lock.withLock { value } }
                set { lock.withLock { value = newValue } }
            }
        }

        func requestedFeed(for urlString: String) async -> String? {
            let captured = Captured()
            MockURLProtocol.responder = { req in
                captured.url = req.url
                return (Data(#"jsonCallback({ "services": [] })"#.utf8), 200)
            }
            let provider = AppleProvider(session: MockURLProtocol.makeSession())
            _ = await provider.fetch(service(urlString, .apple))
            return captured.url?.absoluteString
        }

        let dev = await requestedFeed(for: "https://developer.apple.com/system-status/")
        XCTAssertEqual(dev, "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js")

        let consumer = await requestedFeed(for: "https://www.apple.com/support/systemstatus/")
        XCTAssertEqual(consumer, "https://www.apple.com/support/systemstatus/data/system_status_en_US.js")
    }

    // MARK: - xAI (custom RSS history feed)

    /// A feed of only RESOLVED incidents → operational.
    func testXAIAllResolvedIsOperational() async {
        MockURLProtocol.respond(#"""
        <?xml version="1.0" encoding="UTF-8" ?>
        <rss version="2.0"><channel>
          <item>
            <title>[API] Increased Error rate</title>
            <pubDate>Wed, 17 Jun 2026 12:13:15 GMT</pubDate>
            <description><![CDATA[ <h3>Status: RESOLVED</h3> <p>Severity: available</p> ]]></description>
          </item>
        </channel></rss>
        """#)
        let provider = XAIProvider(session: MockURLProtocol.makeSession())
        let r = await provider.fetch(service("https://status.x.ai/", .xai))
        XCTAssertEqual(r.indicator, .none)
    }

    /// A fixed clock so the recency guard is deterministic.
    private func fixedNow() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 17; c.hour = 18; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "GMT")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testXAIActiveRecentIncidentIsDetected() {
        let xml = #"""
        <rss><channel>
          <item>
            <title>[API] Partial Outage on Image Generation</title>
            <pubDate>Wed, 17 Jun 2026 12:13:15 GMT</pubDate>
            <description><![CDATA[ <h3>Status: INVESTIGATING</h3> <p>Severity: partial outage</p> ]]></description>
          </item>
        </channel></rss>
        """#
        let active = XAIProvider.activeIncidents(in: xml, now: fixedNow())
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.indicator, .major)   // "partial"/"outage" → major
        XCTAssertTrue(active.first?.title.contains("Image Generation") ?? false)
    }

    /// A non-resolved incident whose newest update is old is treated as stale.
    func testXAIStaleUnresolvedIsIgnored() {
        let xml = #"""
        <rss><channel>
          <item>
            <title>[API] Old never-closed blip</title>
            <pubDate>Sat, 07 Jun 2026 12:13:15 GMT</pubDate>
            <description><![CDATA[ <h3>Status: INVESTIGATING</h3> <p>Severity: degraded</p> ]]></description>
          </item>
        </channel></rss>
        """#
        XCTAssertTrue(XAIProvider.activeIncidents(in: xml, now: fixedNow()).isEmpty)
    }

    func testXAISeverityMapping() {
        XCTAssertEqual(XAIProvider.indicator(severity: "major outage", title: "x"), .critical)
        XCTAssertEqual(XAIProvider.indicator(severity: "available", title: "Outage on API"), .major)
        XCTAssertEqual(XAIProvider.indicator(severity: "degraded", title: "Elevated errors"), .minor)
        XCTAssertEqual(XAIProvider.indicator(severity: "maintenance", title: "Scheduled work"), .minor)
    }

    // MARK: - Status.io (scrape pageId → api.status.io summary)

    /// Two-request flow: the page HTML carries `pageId`, then api.status.io
    /// returns the summary. The mock branches on the request URL.
    private func statusIOResponder(pageHTML: String, apiJSON: String) -> @Sendable (URLRequest) -> (Data, Int) {
        { req in
            if (req.url?.absoluteString ?? "").contains("api.status.io") {
                return (Data(apiJSON.utf8), 200)
            }
            return (Data(pageHTML.utf8), 200)
        }
    }

    func testStatusIOOperational() async {
        MockURLProtocol.responder = statusIOResponder(
            pageHTML: "<html><script>var pageId = '5b36dc6502d06804c08349f7';</script></html>",
            apiJSON: #"{"result":{"status_overall":{"status":"Operational","status_code":100}}}"#)
        let r = await StatusIOProvider(session: MockURLProtocol.makeSession())
            .fetch(service("https://status.gitlab.com", .statusio))
        XCTAssertEqual(r.indicator, .none)
    }

    func testStatusIODisruptionIsCritical() async {
        MockURLProtocol.responder = statusIOResponder(
            pageHTML: "<html>pageId = \"deadbeef\"</html>",
            apiJSON: #"{"result":{"status_overall":{"status":"Service Disruption","status_code":400}}}"#)
        let r = await StatusIOProvider(session: MockURLProtocol.makeSession())
            .fetch(service("https://status.gitlab.com", .statusio))
        XCTAssertEqual(r.indicator, .critical)
        XCTAssertTrue(r.description.contains("Disruption"))
    }

    func testStatusIOMissingPageIdIsUnknown() async {
        MockURLProtocol.respond("<html>no page id here</html>")
        let r = await StatusIOProvider(session: MockURLProtocol.makeSession())
            .fetch(service("https://status.gitlab.com", .statusio))
        XCTAssertEqual(r.indicator, .unknown)
    }

    func testStatusIOPageIdExtraction() {
        XCTAssertEqual(StatusIOProvider.pageId(in: "x var pageId = 'abc123' y"), "abc123")
        XCTAssertEqual(StatusIOProvider.pageId(in: "pageId=\"deadBEEF\""), "deadBEEF")
        XCTAssertNil(StatusIOProvider.pageId(in: "no page id present"))
        XCTAssertNil(StatusIOProvider.pageId(in: "pageId = 'not-hex-zzz'"))
    }

    func testStatusIOCodeMapping() {
        XCTAssertEqual(StatusIOProvider.indicator(code: 100, status: "Operational"), .none)
        XCTAssertEqual(StatusIOProvider.indicator(code: 200, status: "Degraded Performance"), .minor)
        XCTAssertEqual(StatusIOProvider.indicator(code: 300, status: "Partial Service Disruption"), .major)
        XCTAssertEqual(StatusIOProvider.indicator(code: 400, status: "Service Disruption"), .critical)
        XCTAssertEqual(StatusIOProvider.indicator(code: nil, status: "All Systems Operational"), .none)
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
