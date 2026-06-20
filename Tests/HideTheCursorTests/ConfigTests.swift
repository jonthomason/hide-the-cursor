import XCTest
@testable import HideTheCursor

final class ConfigTests: XCTestCase {
    func testEmptyIsAll() {
        XCTAssertEqual(ConfigFile.parse(""), ConfigSettings(mode: .all, apps: [], verbose: false))
    }

    func testAppsDefaultToOnly() {
        let settings = ConfigFile.parse("Warp\niTerm\n")
        XCTAssertEqual(settings, ConfigSettings(mode: .only, apps: ["Warp", "iTerm"]))
    }

    func testCommentsAndBlankLinesIgnored() {
        let text = """
        # my terminals
        Warp

          # indented comment
        iTerm
        """
        XCTAssertEqual(ConfigFile.parse(text), ConfigSettings(mode: .only, apps: ["Warp", "iTerm"]))
    }

    func testInlineCommentStripped() {
        let settings = ConfigFile.parse("Warp   # main terminal\n")
        XCTAssertEqual(settings.apps, ["Warp"])
    }

    func testAppNameWithSpacesPreserved() {
        let settings = ConfigFile.parse("Visual Studio Code\n")
        XCTAssertEqual(settings.apps, ["Visual Studio Code"])
    }

    func testModeExcept() {
        let settings = ConfigFile.parse("mode except\nCode\n")
        XCTAssertEqual(settings, ConfigSettings(mode: .except, apps: ["Code"]))
    }

    func testModeAllIgnoresApps() {
        // Explicit "mode all" wins even if apps are listed.
        let settings = ConfigFile.parse("mode all\nWarp\n")
        XCTAssertEqual(settings.mode, .all)
        XCTAssertEqual(settings.apps, ["Warp"])
    }

    func testVerbose() {
        let settings = ConfigFile.parse("verbose\nWarp\n")
        XCTAssertEqual(settings, ConfigSettings(mode: .only, apps: ["Warp"], verbose: true))
    }

    func testModeIsCaseInsensitive() {
        XCTAssertEqual(ConfigFile.parse("MODE Except\nCode").mode, .except)
    }
}
