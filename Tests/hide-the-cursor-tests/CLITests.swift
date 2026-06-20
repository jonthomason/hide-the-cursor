import XCTest
@testable import hide_the_cursor

final class CLITests: XCTestCase {
    func testNoArgumentsIsHelp() throws {
        XCTAssertEqual(try CLI.parse([]), .help)
    }

    func testHelpAliases() throws {
        XCTAssertEqual(try CLI.parse(["help"]), .help)
        XCTAssertEqual(try CLI.parse(["--help"]), .help)
        XCTAssertEqual(try CLI.parse(["-h"]), .help)
    }

    func testVersionAliases() throws {
        XCTAssertEqual(try CLI.parse(["version"]), .version)
        XCTAssertEqual(try CLI.parse(["--version"]), .version)
        XCTAssertEqual(try CLI.parse(["-v"]), .version)
    }

    func testListApp() throws {
        XCTAssertEqual(try CLI.parse(["list-app"]), .listApp)
    }

    func testDoctor() throws {
        XCTAssertEqual(try CLI.parse(["doctor"]), .doctor)
    }

    func testResolve() throws {
        XCTAssertEqual(try CLI.parse(["resolve", "Warp"]), .resolve(["Warp"]))
        XCTAssertEqual(try CLI.parse(["resolve", "Warp", "iTerm"]), .resolve(["Warp", "iTerm"]))
    }

    func testResolveWithoutArgumentsThrows() {
        XCTAssertThrowsError(try CLI.parse(["resolve"])) { error in
            XCTAssertEqual(error as? CLIError, .missingArgument("resolve"))
        }
    }

    func testRunWithoutFilters() throws {
        XCTAssertEqual(try CLI.parse(["run"]), .run(RunOptions()))
    }

    func testRunWithSingleOnly() throws {
        XCTAssertEqual(
            try CLI.parse(["run", "--only", "Warp"]),
            .run(RunOptions(only: ["Warp"])))
    }

    func testRunWithMultipleOnly() throws {
        XCTAssertEqual(
            try CLI.parse(["run", "--only", "Warp", "--only", "iTerm"]),
            .run(RunOptions(only: ["Warp", "iTerm"])))
    }

    func testRunWithOnlyEqualsForm() throws {
        XCTAssertEqual(
            try CLI.parse(["run", "--only=dev.warp.Warp-Stable"]),
            .run(RunOptions(only: ["dev.warp.Warp-Stable"])))
    }

    func testRunWithExcept() throws {
        XCTAssertEqual(
            try CLI.parse(["run", "--except", "Visual Studio Code"]),
            .run(RunOptions(except: ["Visual Studio Code"])))
        XCTAssertEqual(
            try CLI.parse(["run", "--except=Code"]),
            .run(RunOptions(except: ["Code"])))
    }

    func testRunWithVerbose() throws {
        XCTAssertEqual(
            try CLI.parse(["run", "--verbose"]),
            .run(RunOptions(verbose: true)))
        XCTAssertEqual(
            try CLI.parse(["run", "--only", "Warp", "--verbose"]),
            .run(RunOptions(only: ["Warp"], verbose: true)))
        XCTAssertEqual(
            try CLI.parse(["run", "--debug"]),
            .run(RunOptions(verbose: true)))
    }

    func testRunMissingOnlyValueThrows() {
        XCTAssertThrowsError(try CLI.parse(["run", "--only"])) { error in
            XCTAssertEqual(error as? CLIError, .missingValue("--only"))
        }
    }

    func testRunMissingExceptValueThrows() {
        XCTAssertThrowsError(try CLI.parse(["run", "--except"])) { error in
            XCTAssertEqual(error as? CLIError, .missingValue("--except"))
        }
    }

    func testRunEmptyEqualsValueThrows() {
        XCTAssertThrowsError(try CLI.parse(["run", "--only="])) { error in
            XCTAssertEqual(error as? CLIError, .missingValue("--only"))
        }
    }

    func testRunWithBothOnlyAndExceptThrows() {
        XCTAssertThrowsError(try CLI.parse(["run", "--only", "Warp", "--except", "Code"])) { error in
            XCTAssertEqual(error as? CLIError, .conflictingFilters)
        }
    }

    func testUnknownCommandThrows() {
        XCTAssertThrowsError(try CLI.parse(["bogus"])) { error in
            XCTAssertEqual(error as? CLIError, .unknownCommand("bogus"))
        }
    }

    func testUnexpectedArgumentForListAppThrows() {
        XCTAssertThrowsError(try CLI.parse(["list-app", "extra"])) { error in
            XCTAssertEqual(error as? CLIError, .unexpectedArgument("extra"))
        }
    }

    func testUnexpectedFlagForRunThrows() {
        XCTAssertThrowsError(try CLI.parse(["run", "--nope"])) { error in
            XCTAssertEqual(error as? CLIError, .unexpectedArgument("--nope"))
        }
    }
}
