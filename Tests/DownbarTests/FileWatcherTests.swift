import XCTest
@testable import Downbar

/// Editors, `mv`, and the app's own saves all land as atomic replace-by-rename,
/// which swaps the file's inode — the watcher must keep firing across that.
final class FileWatcherTests: XCTestCase {
    private var dir: URL!
    private var file: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("downbar-watcher-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("services.json")
        try Data("[]".utf8).write(to: file)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testFiresOnAtomicReplace() throws {
        let fired = expectation(description: "watcher fired")
        fired.assertForOverFulfill = false
        let watcher = FileWatcher(url: file) { fired.fulfill() }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [file] in
            try? Data("[1]".utf8).write(to: file!, options: .atomic)
        }
        wait(for: [fired], timeout: 5)
        withExtendedLifetime(watcher) {}
    }

    func testSurvivesRepeatedReplaces() throws {
        let fired = expectation(description: "watcher fired after re-arm")
        fired.expectedFulfillmentCount = 2
        fired.assertForOverFulfill = false
        let watcher = FileWatcher(url: file) { fired.fulfill() }

        // Two atomic replaces spaced past the debounce window: the second only
        // fires if the watcher re-attached to the new inode after the first.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [file] in
            try? Data("[1]".utf8).write(to: file!, options: .atomic)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) { [file] in
            try? Data("[2]".utf8).write(to: file!, options: .atomic)
        }
        wait(for: [fired], timeout: 8)
        withExtendedLifetime(watcher) {}
    }
}
