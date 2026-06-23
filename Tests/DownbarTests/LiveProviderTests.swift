import XCTest
@testable import Downbar

/// Live-feed canary: hits a representative *real* status page per provider kind
/// over the network and asserts the feed still parses (result is not `.unknown`).
/// A `.unknown` here means the provider couldn't decode the wild response —
/// i.e. the upstream format drifted and our adapter needs updating.
///
/// These tests are **skipped by default** so the normal offline `swift test`
/// stays green and deterministic. The weekly `live-canary` GitHub workflow runs
/// them with `RUN_LIVE_TESTS=1` so format drift in production fails loudly.
final class LiveProviderTests: XCTestCase {

    /// Skips unless explicitly opted in. Every live test calls this first.
    private func requireLive() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_TESTS"] == "1",
            "live network tests — set RUN_LIVE_TESTS=1")
    }

    /// Fetches the real feed and fails if the adapter couldn't parse it.
    private func assertParses(
        _ provider: StatusProvider,
        _ service: Service,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await provider.fetch(service)
        XCTAssertNotEqual(
            result.indicator, .unknown,
            "\(service.name) feed did not parse — drift? (\(result.description))",
            file: file, line: line)
    }

    // MARK: - Statuspage.io (Cloudflare)

    func testStatuspageLive() async throws {
        try requireLive()
        let service = Service(
            name: "Cloudflare",
            url: URL(string: "https://www.cloudflarestatus.com")!,
            provider: .statuspage)
        await assertParses(StatuspageProvider(), service)
    }

    // MARK: - Instatus

    func testInstatusLive() async throws {
        try requireLive()
        let service = Service(
            name: "Perplexity",
            url: URL(string: "https://status.perplexity.com")!,
            provider: .instatus)
        await assertParses(InstatusProvider(), service)
    }

    // MARK: - xAI (custom RSS feed)

    func testXAILive() async throws {
        try requireLive()
        let service = Service(
            name: "xAI",
            url: URL(string: "https://status.x.ai/")!,
            provider: .xai)
        await assertParses(XAIProvider(), service)
    }

    // MARK: - AWS Health (fixed feed)

    func testAWSLive() async throws {
        try requireLive()
        let service = Service(
            name: "Amazon Web Services",
            url: URL(string: "https://health.aws.amazon.com/health/status")!,
            provider: .aws)
        await assertParses(AWSProvider(), service)
    }

    // MARK: - Apple System Status (fixed feed)

    func testAppleLive() async throws {
        try requireLive()
        let service = Service(
            name: "Apple Developer",
            url: URL(string: "https://developer.apple.com/system-status/")!,
            provider: .apple)
        await assertParses(AppleProvider(), service)
    }

    func testAppleConsumerLive() async throws {
        try requireLive()
        let service = Service(
            name: "Apple System Status",
            url: URL(string: "https://www.apple.com/support/systemstatus/")!,
            provider: .apple)
        await assertParses(AppleProvider(), service)
    }

    // MARK: - Google Cloud (fixed feed)

    func testGCPLive() async throws {
        try requireLive()
        let service = Service(
            name: "Google Cloud",
            url: URL(string: "https://status.cloud.google.com")!,
            provider: .gcp)
        await assertParses(GCPProvider(), service)
    }

    // MARK: - Azure (fixed RSS feed)

    func testAzureLive() async throws {
        try requireLive()
        let service = Service(
            name: "Microsoft Azure",
            url: URL(string: "https://azure.status.microsoft/en-us/status")!,
            provider: .azure)
        await assertParses(AzureProvider(), service)
    }

    // MARK: - Generic website / server

    func testWebsiteLive() async throws {
        try requireLive()
        let service = Service(
            name: "Apple",
            url: URL(string: "https://www.apple.com")!,
            provider: .website)
        await assertParses(WebsiteProvider(), service)
    }
}
