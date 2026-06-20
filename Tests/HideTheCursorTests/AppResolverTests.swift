import XCTest
@testable import HideTheCursor

/// These touch LaunchServices / the filesystem, so they assert against Terminal,
/// which ships with every macOS install at a stable location.
final class AppResolverTests: XCTestCase {
    func testResolvesByAppName() {
        XCTAssertEqual(AppResolver.resolveBundleID("Terminal"), "com.apple.Terminal")
    }

    func testResolvesByDotAppFilename() {
        XCTAssertEqual(AppResolver.resolveBundleID("Terminal.app"), "com.apple.Terminal")
    }

    func testBundleIDPassesThrough() {
        XCTAssertEqual(AppResolver.resolveBundleID("com.apple.Terminal"), "com.apple.Terminal")
    }

    func testUnknownAppReturnsNil() {
        XCTAssertNil(AppResolver.resolveBundleID("No Such App 8675309 zzz"))
    }
}
