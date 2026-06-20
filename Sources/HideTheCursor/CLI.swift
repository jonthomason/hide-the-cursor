import Foundation

/// Options for the `run` command. Resolution of app names to bundle ids happens
/// later (at runtime), so this stays a pure, testable value.
public struct RunOptions: Equatable {
    public var only: [String]
    public var except: [String]
    public var verbose: Bool

    public init(only: [String] = [], except: [String] = [], verbose: Bool = false) {
        self.only = only
        self.except = except
        self.verbose = verbose
    }
}

/// A parsed command line. Kept value-typed so it is easy to unit test.
public enum Command: Equatable {
    case run(RunOptions)
    case listApp
    case resolve([String])
    case doctor
    case help
    case version
}

public enum CLIError: Error, CustomStringConvertible, Equatable {
    case unknownCommand(String)
    case missingValue(String)
    case unexpectedArgument(String)
    case missingArgument(String)
    case conflictingFilters

    public var description: String {
        switch self {
        case .unknownCommand(let name):
            return "unknown command '\(name)'"
        case .missingValue(let flag):
            return "expected a value after '\(flag)'"
        case .unexpectedArgument(let arg):
            return "unexpected argument '\(arg)'"
        case .missingArgument(let command):
            return "command '\(command)' needs at least one app name or bundle id"
        case .conflictingFilters:
            return "--only and --except cannot be used together"
        }
    }
}

/// Hand-rolled argument parsing. No third-party dependency on purpose: the grammar
/// is small, and this keeps the build boring and fast.
public enum CLI {
    /// Parse arguments *without* the leading program name.
    public static func parse(_ arguments: [String]) throws -> Command {
        guard let first = arguments.first else {
            return .help
        }
        let rest = Array(arguments.dropFirst())

        switch first {
        case "run":
            return try parseRun(rest)
        case "list-app":
            try requireNoExtraArguments(rest)
            return .listApp
        case "resolve":
            guard !rest.isEmpty else { throw CLIError.missingArgument("resolve") }
            return .resolve(rest)
        case "doctor":
            try requireNoExtraArguments(rest)
            return .doctor
        case "help", "--help", "-h":
            return .help
        case "version", "--version", "-v":
            return .version
        default:
            throw CLIError.unknownCommand(first)
        }
    }

    private static func parseRun(_ arguments: [String]) throws -> Command {
        var only: [String] = []
        var except: [String] = []
        var verbose = false
        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--only":
                only.append(try value(after: &index, in: arguments, flag: "--only"))
            case "--except":
                except.append(try value(after: &index, in: arguments, flag: "--except"))
            case "--verbose", "--debug":
                verbose = true
                index += 1
            default:
                if let value = stripPrefix("--only=", from: arg) {
                    guard !value.isEmpty else { throw CLIError.missingValue("--only") }
                    only.append(value)
                    index += 1
                } else if let value = stripPrefix("--except=", from: arg) {
                    guard !value.isEmpty else { throw CLIError.missingValue("--except") }
                    except.append(value)
                    index += 1
                } else {
                    throw CLIError.unexpectedArgument(arg)
                }
            }
        }
        if !only.isEmpty && !except.isEmpty {
            throw CLIError.conflictingFilters
        }
        return .run(RunOptions(only: only, except: except, verbose: verbose))
    }

    /// Read the value that follows a `--flag` and advance the cursor past both.
    private static func value(
        after index: inout Int, in arguments: [String], flag: String
    ) throws -> String {
        guard index + 1 < arguments.count else {
            throw CLIError.missingValue(flag)
        }
        let value = arguments[index + 1]
        index += 2
        return value
    }

    private static func requireNoExtraArguments(_ arguments: [String]) throws {
        if let extra = arguments.first {
            throw CLIError.unexpectedArgument(extra)
        }
    }

    private static func stripPrefix(_ prefix: String, from value: String) -> String? {
        guard value.hasPrefix(prefix) else { return nil }
        return String(value.dropFirst(prefix.count))
    }
}
