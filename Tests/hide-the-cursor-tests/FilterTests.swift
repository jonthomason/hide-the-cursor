import XCTest
@testable import hide_the_cursor

final class FilterTests: XCTestCase {
    func testAllAllowsEverything() {
        let filter = ResolvedFilter.all
        XCTAssertTrue(filter.allows(bundleID: "dev.warp.Warp-Stable", name: "Warp"))
        XCTAssertTrue(filter.allows(bundleID: nil, name: nil))
    }

    func testOnlyMatchesByBundleID() {
        let filter = ResolvedFilter(mode: .only, bundleIDs: ["dev.warp.Warp-Stable"])
        XCTAssertTrue(filter.allows(bundleID: "dev.warp.Warp-Stable", name: "Warp"))
        XCTAssertFalse(filter.allows(bundleID: "com.apple.Terminal", name: "Terminal"))
    }

    func testOnlyMatchesByDisplayNameToken() {
        // Token captured from the user's "--only Warp", lowercased.
        let filter = ResolvedFilter(mode: .only, tokens: ["warp"])
        XCTAssertTrue(filter.allows(bundleID: "dev.warp.Warp-Stable", name: "Warp"))
        XCTAssertFalse(filter.allows(bundleID: "com.apple.Terminal", name: "Terminal"))
    }

    func testOnlyMatchesByBundleIDToken() {
        let filter = ResolvedFilter(mode: .only, tokens: ["dev.warp.warp-stable"])
        XCTAssertTrue(filter.allows(bundleID: "dev.warp.Warp-Stable", name: "Warp"))
    }

    func testExceptIsInverse() {
        let filter = ResolvedFilter(mode: .except, tokens: ["code"])
        XCTAssertFalse(filter.allows(bundleID: "com.microsoft.VSCode", name: "Code"))
        XCTAssertTrue(filter.allows(bundleID: "dev.warp.Warp-Stable", name: "Warp"))
        // Unknown frontmost app: not in the except list, so still act.
        XCTAssertTrue(filter.allows(bundleID: nil, name: nil))
    }
}
