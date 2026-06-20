import XCTest
@testable import hide_the_cursor

final class SettingsResolverTests: XCTestCase {
    func testNoCliNoConfigIsAll() {
        let result = SettingsResolver.resolve(options: RunOptions(), config: .empty)
        XCTAssertEqual(result, EffectiveSettings(mode: .all, apps: [], verbose: false))
    }

    func testConfigUsedWhenNoCliFilter() {
        let config = ConfigSettings(mode: .only, apps: ["Warp", "cmux"])
        let result = SettingsResolver.resolve(options: RunOptions(), config: config)
        XCTAssertEqual(result, EffectiveSettings(mode: .only, apps: ["Warp", "cmux"], verbose: false))
    }

    func testCliOnlyOverridesConfig() {
        let config = ConfigSettings(mode: .except, apps: ["Code"])
        let result = SettingsResolver.resolve(options: RunOptions(only: ["Warp"]), config: config)
        XCTAssertEqual(result, EffectiveSettings(mode: .only, apps: ["Warp"], verbose: false))
    }

    func testCliExceptOverridesConfig() {
        let config = ConfigSettings(mode: .only, apps: ["Warp"])
        let result = SettingsResolver.resolve(options: RunOptions(except: ["Code"]), config: config)
        XCTAssertEqual(result, EffectiveSettings(mode: .except, apps: ["Code"], verbose: false))
    }

    func testVerboseIsAdditive() {
        let fromCli = SettingsResolver.resolve(
            options: RunOptions(verbose: true), config: .empty)
        XCTAssertTrue(fromCli.verbose)

        let fromConfig = SettingsResolver.resolve(
            options: RunOptions(), config: ConfigSettings(verbose: true))
        XCTAssertTrue(fromConfig.verbose)

        let neither = SettingsResolver.resolve(options: RunOptions(), config: .empty)
        XCTAssertFalse(neither.verbose)
    }
}
