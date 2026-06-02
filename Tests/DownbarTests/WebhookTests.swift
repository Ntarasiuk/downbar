import XCTest
@testable import Downbar

/// Captures the outgoing request so tests can assert method/headers/body.
private final class RequestBox: @unchecked Sendable {
    var request: URLRequest?
}

/// Reads a (possibly streamed) request body — URLSession converts `httpBody`
/// into `httpBodyStream` before it reaches the protocol.
private func bodyData(_ request: URLRequest?) -> Data {
    guard let request else { return Data() }
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

final class WebhookTests: XCTestCase {
    private var originalURLString = ""
    private var originalSession: URLSession!

    override func setUp() {
        super.setUp()
        originalURLString = WebhookPrefs.urlString
        originalSession = Webhook.session
    }

    override func tearDown() {
        WebhookPrefs.urlString = originalURLString
        Webhook.session = originalSession
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    // MARK: - WebhookPrefs URL parsing

    func testURLParsingAcceptsHTTPS() {
        WebhookPrefs.urlString = "https://hooks.slack.com/services/T/B/X"
        XCTAssertNotNil(WebhookPrefs.url)
        XCTAssertTrue(WebhookPrefs.isConfigured)
    }

    func testURLParsingTrimsWhitespace() {
        WebhookPrefs.urlString = "  https://example.com/hook \n"
        XCTAssertEqual(WebhookPrefs.url?.absoluteString, "https://example.com/hook")
    }

    func testURLParsingRejectsBlank() {
        WebhookPrefs.urlString = "   "
        XCTAssertNil(WebhookPrefs.url)
        XCTAssertFalse(WebhookPrefs.isConfigured)
    }

    func testURLParsingRejectsNonHTTPScheme() {
        WebhookPrefs.urlString = "ftp://example.com/hook"
        XCTAssertNil(WebhookPrefs.url)
    }

    func testURLParsingRejectsSchemeOnly() {
        WebhookPrefs.urlString = "https://"
        XCTAssertNil(WebhookPrefs.url)
    }

    // MARK: - Payload shape

    func testDownPayloadHasSlackAndDiscordFields() {
        let payload = Webhook.makePayload(
            event: .down,
            name: "Cloudflare",
            page: URL(string: "https://www.cloudflarestatus.com")!,
            indicator: .critical,
            message: "Major outage in WAF"
        )
        // Same human text in both the Slack (`text`) and Discord (`content`) keys.
        XCTAssertEqual(payload["text"], payload["content"])
        XCTAssertTrue(payload["text"]!.contains("Cloudflare"))
        XCTAssertTrue(payload["text"]!.contains("Major outage in WAF"))
        XCTAssertTrue(payload["text"]!.contains("🔴"))           // critical emoji
        XCTAssertEqual(payload["event"], "down")
        XCTAssertEqual(payload["service"], "Cloudflare")
        XCTAssertEqual(payload["severity"], "critical")
        XCTAssertEqual(payload["description"], "Major outage in WAF")
        XCTAssertEqual(payload["url"], "https://www.cloudflarestatus.com")
    }

    func testRecoveredPayloadMessage() {
        let payload = Webhook.makePayload(
            event: .recovered,
            name: "GitHub",
            page: URL(string: "https://www.githubstatus.com")!,
            indicator: .none,
            message: "ignored"
        )
        XCTAssertTrue(payload["text"]!.contains("GitHub recovered"))
        XCTAssertTrue(payload["text"]!.contains("✅"))
        XCTAssertEqual(payload["event"], "recovered")
        XCTAssertEqual(payload["severity"], "operational")
    }

    func testTestPayloadMessage() {
        let payload = Webhook.makePayload(
            event: .test,
            name: "Downbar",
            page: URL(string: "https://github.com")!,
            indicator: .none,
            message: "Test alert from Downbar"
        )
        XCTAssertEqual(payload["event"], "test")
        XCTAssertTrue(payload["text"]!.lowercased().contains("test"))
    }

    func testSeverityEmojiVariesByIndicator() {
        func emoji(_ i: Indicator) -> String {
            Webhook.makePayload(event: .down, name: "x",
                                page: URL(string: "https://x.com")!,
                                indicator: i, message: "m")["text"]!
        }
        XCTAssertTrue(emoji(.minor).contains("⚠️"))
        XCTAssertTrue(emoji(.major).contains("🟠"))
        XCTAssertTrue(emoji(.critical).contains("🔴"))
    }

    // MARK: - Delivery (sendTest over a mock session)

    func testSendTestSucceedsOn2xx() async {
        Webhook.session = MockURLProtocol.makeSession()
        MockURLProtocol.respond("ok", status: 200)
        let ok = await Webhook.sendTest(to: URL(string: "https://example.com/hook")!)
        XCTAssertTrue(ok)
    }

    func testSendTestSucceedsOn204() async {
        Webhook.session = MockURLProtocol.makeSession()
        MockURLProtocol.respond("", status: 204)
        let ok = await Webhook.sendTest(to: URL(string: "https://example.com/hook")!)
        XCTAssertTrue(ok)
    }

    func testSendTestFailsOn500() async {
        Webhook.session = MockURLProtocol.makeSession()
        MockURLProtocol.respond("boom", status: 500)
        let ok = await Webhook.sendTest(to: URL(string: "https://example.com/hook")!)
        XCTAssertFalse(ok)
    }

    func testSendTestFailsOn404() async {
        Webhook.session = MockURLProtocol.makeSession()
        MockURLProtocol.respond("nope", status: 404)
        let ok = await Webhook.sendTest(to: URL(string: "https://example.com/hook")!)
        XCTAssertFalse(ok)
    }

    func testSendTestPostsJSONBody() async throws {
        Webhook.session = MockURLProtocol.makeSession()
        let box = RequestBox()
        MockURLProtocol.responder = { request in
            box.request = request
            return (Data("ok".utf8), 200)
        }

        _ = await Webhook.sendTest(to: URL(string: "https://example.com/hook")!)

        XCTAssertEqual(box.request?.httpMethod, "POST")
        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let data = bodyData(box.request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(json["event"], "test")
        XCTAssertNotNil(json["text"])
        XCTAssertNotNil(json["content"])
    }
}
