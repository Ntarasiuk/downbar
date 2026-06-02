import XCTest
@testable import Downbar

/// Guards the curated catalog and the first-launch seed against drift: every
/// entry must be uniquely identifiable, every seeded service must exist in the
/// catalog (so it shows as already-enabled), and every URL must parse.
final class CatalogIntegrityTests: XCTestCase {

    func testCatalogIDsAreUnique() {
        let ids = ServiceCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate catalog entry id (provider:host)")
    }

    func testCatalogURLsParse() {
        for entry in ServiceCatalog.all {
            XCTAssertNotNil(entry.url.host(), "Entry \(entry.name) has no host")
            XCTAssertEqual(entry.url.scheme, "https", "Entry \(entry.name) is not https")
        }
    }

    func testEverySeedHostAppearsInCatalog() {
        let catalogIDs = Set(ServiceCatalog.all.map(\.id))
        for service in ServiceStore.seed {
            let host = service.url.host()?.lowercased() ?? ""
            let id = "\(service.provider.rawValue):\(host)"
            XCTAssertTrue(
                catalogIDs.contains(id),
                "Seeded service \(service.name) (\(id)) is missing from the catalog")
        }
    }

    func testSeedServicesHaveValidURLs() {
        for service in ServiceStore.seed {
            XCTAssertNotNil(service.url.host(), "Seed \(service.name) has no host")
        }
    }

    func testEveryCatalogCategoryIsListed() {
        let listed = Set(ServiceCatalog.categories)
        for entry in ServiceCatalog.all {
            XCTAssertTrue(
                listed.contains(entry.category),
                "Category \"\(entry.category)\" of \(entry.name) is not in the display order list")
        }
    }
}
