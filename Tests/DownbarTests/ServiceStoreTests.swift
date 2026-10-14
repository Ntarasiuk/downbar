import XCTest
@testable import Downbar

/// `services.json` is a supported hand/AI-editing surface, so loading must be
/// forgiving: minimal entries work, malformed entries are dropped individually,
/// and exact duplicates collapse.
final class ServiceStoreTests: XCTestCase {
    private var dir: URL!
    private var store: ServiceStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("downbar-store-tests-\(UUID().uuidString)", isDirectory: true)
        store = ServiceStore(directory: dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ json: String) throws {
        try json.data(using: .utf8)!.write(to: store.fileURL)
    }

    func testMissingFileFallsBackToSeed() {
        XCTAssertEqual(store.load(), ServiceStore.seed)
    }

    func testEntryWithoutIDOrProviderDecodes() throws {
        try write(#"[{"name": "Sentry", "url": "https://status.sentry.io"}]"#)
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Sentry")
        XCTAssertEqual(loaded[0].provider, .statuspage)
    }

    func testMalformedEntryIsDroppedNotFatal() throws {
        try write("""
        [
          {"name": "Sentry", "url": "https://status.sentry.io", "provider": "statuspage"},
          {"nope": true},
          {"name": "Checkly", "url": "https://checklyhq.instatus.com", "provider": "instatus"}
        ]
        """)
        XCTAssertEqual(store.load().map(\.name), ["Sentry", "Checkly"])
    }

    func testInvalidIDAndUnknownProviderAreTolerated() throws {
        try write(#"[{"id": "svc-1", "name": "Thing", "url": "https://example.com", "provider": "mystery"}]"#)
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].provider, .statuspage)
    }

    func testExactDuplicatesCollapse() throws {
        try write("""
        [
          {"name": "Sentry", "url": "https://status.sentry.io"},
          {"name": "Sentry again", "url": "https://status.sentry.io"}
        ]
        """)
        XCTAssertEqual(store.load().count, 1)
    }

    func testSaveRoundTripsAndIsPrettyPrinted() throws {
        let services = [Service(name: "GitHub", url: URL(string: "https://www.githubstatus.com")!)]
        store.save(services)
        XCTAssertEqual(store.load(), services)
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\n"), "Config should be pretty-printed for hand editing")
        XCTAssertTrue(text.contains("https://www.githubstatus.com"), "Slashes should not be escaped")
    }

    func testComponentFilterRoundTrips() throws {
        let services = [Service(name: "Cloudflare", url: URL(string: "https://www.cloudflarestatus.com")!,
                                components: ["2k1qvzk3763q"])]
        store.save(services)
        XCTAssertEqual(store.load(), services)
        // Unfiltered services don't grow a `components` key.
        store.save([Service(name: "GitHub", url: URL(string: "https://www.githubstatus.com")!)])
        XCTAssertFalse(try String(contentsOf: store.fileURL, encoding: .utf8).contains("components"))
    }

    func testEnsureOnDiskWritesOnceAndNeverOverwrites() throws {
        store.ensureOnDisk(ServiceStore.seed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        let custom = [Service(name: "Only", url: URL(string: "https://example.com")!, provider: .website)]
        store.save(custom)
        store.ensureOnDisk(ServiceStore.seed)
        XCTAssertEqual(store.load(), custom)
    }
}

/// The copied AI prompt must stay truthful to the app: every catalog entry
/// present, the real config path baked in, and only real provider raw values.
final class AgentPromptTests: XCTestCase {
    func testPromptContainsEveryCatalogEntryAndConfigPath() {
        let prompt = AgentPrompt.text(configPath: "/tmp/fake/services.json")
        XCTAssertTrue(prompt.contains("/tmp/fake/services.json"))
        for entry in ServiceCatalog.all {
            XCTAssertTrue(prompt.contains(entry.url.absoluteString), "Missing \(entry.name) URL")
        }
        for kind in ProviderKind.allCases {
            XCTAssertTrue(prompt.contains(kind.rawValue), "Missing provider \(kind.rawValue)")
        }
    }
}
