import XCTest
import AppKit
@testable import Downbar

/// The menu-bar panel list collapsed to zero height because SwiftUI's
/// `ScrollView` reports no intrinsic size inside `MenuBarExtra(.window)`.
/// `IntrinsicScrollView` fixes that by surfacing its document view's height
/// (capped at `maxHeight`). These tests pin that capping contract.
@MainActor
final class IntrinsicScrollViewTests: XCTestCase {

    /// A document view with a caller-controlled intrinsic height.
    private final class FixedHeightView: NSView {
        var height: CGFloat
        init(height: CGFloat) { self.height = height; super.init(frame: .zero) }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: height)
        }
    }

    private func scrollView(maxHeight: CGFloat, contentHeight: CGFloat) -> IntrinsicScrollView {
        let sv = IntrinsicScrollView(maxHeight: maxHeight)
        sv.documentView = FixedHeightView(height: contentHeight)
        return sv
    }

    func testReportsContentHeightWhenUnderCap() {
        let sv = scrollView(maxHeight: 480, contentHeight: 200)
        XCTAssertEqual(sv.intrinsicContentSize.height, 200)
    }

    func testCapsAtMaxHeightWhenContentExceedsIt() {
        let sv = scrollView(maxHeight: 480, contentHeight: 1000)
        XCTAssertEqual(sv.intrinsicContentSize.height, 480)
    }

    func testHeightEqualToCapIsNotClamped() {
        let sv = scrollView(maxHeight: 480, contentHeight: 480)
        XCTAssertEqual(sv.intrinsicContentSize.height, 480)
    }

    /// A document view that hasn't laid out yet reports a zero intrinsic
    /// height; the scroll view must defer to `noIntrinsicMetric` rather than
    /// pinning itself to zero (which is the bug this class works around).
    func testZeroContentHeightYieldsNoIntrinsicMetric() {
        let sv = scrollView(maxHeight: 480, contentHeight: 0)
        XCTAssertEqual(sv.intrinsicContentSize.height, NSView.noIntrinsicMetric)
    }

    /// Width is always flexible — only height is driven/capped.
    func testWidthIsAlwaysNoIntrinsicMetric() {
        XCTAssertEqual(scrollView(maxHeight: 480, contentHeight: 200).intrinsicContentSize.width,
                       NSView.noIntrinsicMetric)
        XCTAssertEqual(scrollView(maxHeight: 480, contentHeight: 1000).intrinsicContentSize.width,
                       NSView.noIntrinsicMetric)
    }
}
