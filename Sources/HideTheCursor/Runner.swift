import AppKit
import CoreGraphics
import Foundation

/// Executes a parsed `Command`. Returns the process exit code (the `run` case
/// blocks in CFRunLoopRun until a signal arrives).
public enum Runner {
    public static let version = "0.1.0"

    public static func run(_ command: Command) -> Int32 {
        switch command {
        case .help:
            printUsage()
            return 0
        case .version:
            print("hide-the-cursor \(version)")
            return 0
        case .listApp:
            return listApp()
        case .resolve(let tokens):
            return resolve(tokens)
        case .doctor:
            return PermissionDoctor.run()
        case .run(let options):
            return runLoop(options)
        }
    }

    public static func printUsage() {
        print("""
        hide-the-cursor \(version)
        Hide the macOS mouse cursor while typing; macOS reveals it on mouse move.

        USAGE:
          hide-the-cursor <command>

        COMMANDS:
          run [--only <app> ...] [--except <app> ...] [--verbose]
                                  Hide the cursor on every key press.
                                  --only:   act only for these apps.
                                  --except: act for all apps but these.
                                  <app> may be an app name ("Warp"), a ".app"
                                  filename, or a bundle id. --only and --except
                                  are mutually exclusive. With no filter, acts
                                  for all apps.
          list-app                Print the frontmost app's name and bundle id.
          resolve <app> ...       Show the bundle id each app name resolves to.
          doctor                  Check permissions and that the tap can be made.
          help                    Show this help.
          version                 Show the version.

        EXAMPLES:
          hide-the-cursor list-app
          hide-the-cursor run
          hide-the-cursor run --only Warp
          hide-the-cursor run --only Warp --only iTerm
          hide-the-cursor run --except "Visual Studio Code"
          hide-the-cursor resolve Warp iTerm
        """)
    }

    private static func listApp() -> Int32 {
        let (name, bundleID) = ActiveApp.frontmost()
        print("Name: \(name ?? "(unknown)")")
        print("Bundle ID: \(bundleID ?? "(unknown)")")
        if let name {
            print("")
            print("Use it with:  hide-the-cursor run --only \"\(name)\"")
        }
        return 0
    }

    private static func resolve(_ tokens: [String]) -> Int32 {
        var allResolved = true
        for token in tokens {
            if let identifier = AppResolver.resolveBundleID(token) {
                print("\(token) -> \(identifier)")
            } else {
                print("\(token) -> (not found)")
                allResolved = false
            }
        }
        return allResolved ? 0 : 1
    }

    private static func runLoop(_ options: RunOptions) -> Int32 {
        // Register as an invisible (accessory) GUI app so AppKit's cursor
        // machinery is live, and opt into changing the cursor from the
        // background (the terminal, not us, stays frontmost).
        NSApplication.shared.setActivationPolicy(.accessory)
        let backgroundCursorEnabled = BackgroundCursor.enable()
        if !backgroundCursorEnabled {
            Log.warn("could not enable background cursor control; "
                + "the cursor may only hide while this process is frontmost")
        }

        let (filter, summary) = buildFilter(options)

        let manager = EventTapManager(filter: filter, verbose: options.verbose)
        guard manager.start() else {
            FileHandle.standardError.write(
                Data("hide-the-cursor: could not create the keyboard event tap.\n\n".utf8))
            PermissionDoctor.printPermissionInstructions()
            return 1
        }

        activeManager = manager
        installSignalHandlers()

        print("hide-the-cursor: hiding the cursor while typing in \(summary). "
            + "Press Ctrl-C to stop.")
        if options.verbose {
            Log.debug("verbose mode on; backgroundCursorControl=\(backgroundCursorEnabled); "
                + "activationPolicy=accessory")
        }

        CFRunLoopRun()
        return 0
    }

    /// Resolve the run options into a runtime filter and a human-readable summary.
    /// Logs how each app name resolved (and warns about ones that didn't).
    private static func buildFilter(_ options: RunOptions) -> (ResolvedFilter, String) {
        let mode: FilterMode
        let rawTokens: [String]
        if !options.only.isEmpty {
            mode = .only
            rawTokens = options.only
        } else if !options.except.isEmpty {
            mode = .except
            rawTokens = options.except
        } else {
            return (.all, "all apps")
        }

        var bundleIDs = Set<String>()
        var tokens = Set<String>()
        var labels: [String] = []
        for token in rawTokens {
            tokens.insert(token.lowercased())
            if let identifier = AppResolver.resolveBundleID(token) {
                bundleIDs.insert(identifier)
                labels.append(identifier == token ? identifier : "\(token) (\(identifier))")
            } else {
                Log.warn("could not resolve '\(token)' to an installed app; "
                    + "will match by display name only")
                labels.append("\(token) (unresolved)")
            }
        }

        let list = labels.joined(separator: ", ")
        let summary = mode == .only ? list : "all apps except \(list)"
        return (ResolvedFilter(mode: mode, tokens: tokens, bundleIDs: bundleIDs), summary)
    }
}

// MARK: - Signal handling

// Held for the lifetime of the process while `run` is active.
private var activeManager: EventTapManager?
private var signalSources: [DispatchSourceSignal] = []

private func installSignalHandlers() {
    for sig in [SIGINT, SIGTERM] {
        // Ignore the default disposition so the DispatchSource sees the signal.
        signal(sig, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler {
            activeManager?.stop()
            activeManager = nil
            exit(0)
        }
        source.resume()
        signalSources.append(source)
    }
}
