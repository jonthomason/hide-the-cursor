import AppKit
import CoreGraphics
import Foundation

/// Executes a parsed `Command`. Returns the process exit code (the `run` case
/// blocks in CFRunLoopRun until a signal arrives).
public enum Runner {
    public static let version = "0.5.0"

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
        case .list(let options):
            return listApps(options)
        case .reloadConfig:
            return reloadConfig()
        case .run(let options):
            return options.once ? runOnce() : runLoop(options)
        }
    }

    public static func printUsage() {
        print("""
        hide-the-cursor \(version)
        Hide the macOS mouse cursor while typing; macOS reveals it on mouse move.

        USAGE:
          hide-the-cursor <command>

        COMMANDS:
          run [--only <app> ...] [--except <app> ...]
              [--config <path>] [--no-config] [--once] [--verbose]
                                  Hide the cursor on every key press.
                                  --only:   act only for these apps.
                                  --except: act for all apps but these.
                                  <app> may be an app name ("Warp"), a ".app"
                                  filename, or a bundle id. --only and --except
                                  are mutually exclusive. With no filter, acts
                                  for all apps.
                                  Reads ~/.config/hide-the-cursor/config if
                                  present (--only/--except override it); use
                                  `reload-config` to reload it without restarting.
                                  --once: hide the cursor once now (self-test).
          list                    Show which apps cursor-hiding is enabled for
                                  (from the config file, or the flags you pass).
          reload-config           Tell the running daemon to re-read its config
                                  (no restart, so no permission re-prompt).
          list-app                Print the frontmost app's name and bundle id.
          resolve <app> ...       Show the bundle id each app name resolves to.
          doctor                  Check permissions and that the tap can be made.
          help                    Show this help.
          version                 Show the version.

        EXAMPLES:
          hide-the-cursor list-app
          hide-the-cursor run
          hide-the-cursor run --only Warp
          hide-the-cursor run --except "Visual Studio Code"
          hide-the-cursor run --once
          hide-the-cursor list
          hide-the-cursor reload-config
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

    /// `list`: print which apps cursor-hiding is configured for, each resolved to
    /// its bundle id. Reflects the config file (and any --only/--except/--config
    /// flags), i.e. exactly what `run` would act on.
    private static func listApps(_ options: RunOptions) -> Int32 {
        let (config, configPath) = loadConfig(options)
        let effective = SettingsResolver.resolve(options: options, config: config)

        if effective.mode == .all || effective.apps.isEmpty {
            print("Enabled for: all apps (no app filter configured).")
        } else {
            print(effective.mode == .only
                ? "Enabled for these apps:"
                : "Enabled for all apps except:")
            for app in effective.apps {
                if let identifier = AppResolver.resolveBundleID(app) {
                    print(identifier == app ? "  • \(app)" : "  • \(app)  →  \(identifier)")
                } else {
                    print("  • \(app)  (not installed?)")
                }
            }
        }

        let source: String
        if !options.only.isEmpty || !options.except.isEmpty {
            source = "command-line flags"
        } else if let configPath {
            source = configPath
        } else {
            source = "no config file (default: \(ConfigFile.defaultPath()))"
        }
        print("")
        print("Source: \(source)")
        return 0
    }

    /// `reload-config`: signal the running daemon to re-read its config (SIGHUP),
    /// so config edits apply without a restart (which would re-prompt for
    /// permission). Finds processes by exact executable *name* (so a shell whose
    /// command line merely contains "hide-the-cursor run" is not matched) and
    /// signals all of them except this process.
    private static func reloadConfig() -> Int32 {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-x", "hide-the-cursor"]
        let output = Pipe()
        pgrep.standardOutput = output
        do {
            try pgrep.run()
        } catch {
            Log.warn("could not run /usr/bin/pgrep: \(error.localizedDescription)")
            return 1
        }
        pgrep.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let myself = getpid()
        let pids = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 != myself }

        guard !pids.isEmpty else {
            print("hide-the-cursor: no running daemon found "
                + "(start it with `brew services start hide-the-cursor`).")
            return 1
        }
        for pid in pids {
            kill(pid, SIGHUP)
        }
        print("hide-the-cursor: told the running daemon to reload its config"
            + (pids.count > 1 ? " (\(pids.count) processes)." : "."))
        return 0
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

        let (config, loadedConfigPath) = loadConfig(options)
        let effective = SettingsResolver.resolve(options: options, config: config)
        let verbose = effective.verbose
        let (filter, summary) = buildFilter(mode: effective.mode, rawTokens: effective.apps)

        let manager = EventTapManager(filter: filter, verbose: verbose)
        guard manager.start() else {
            FileHandle.standardError.write(
                Data("hide-the-cursor: could not create the keyboard event tap.\n\n".utf8))
            PermissionDoctor.printPermissionInstructions()
            return 1
        }

        activeManager = manager
        // SIGHUP re-reads the config file and swaps the filter, no restart needed.
        reloadHandler = {
            let (newConfig, _) = loadConfig(options)
            let merged = SettingsResolver.resolve(options: options, config: newConfig)
            let (newFilter, newSummary) = buildFilter(mode: merged.mode, rawTokens: merged.apps)
            manager.update(filter: newFilter, verbose: merged.verbose)
            print("hide-the-cursor: reloaded config — now hiding the cursor while typing in "
                + "\(newSummary).")
        }
        installSignalHandlers()

        if let loadedConfigPath {
            print("hide-the-cursor: loaded config from \(loadedConfigPath)")
        }
        print("hide-the-cursor: hiding the cursor while typing in \(summary). "
            + "Press Ctrl-C to stop (`hide-the-cursor reload-config` reloads the config).")
        if verbose {
            Log.debug("verbose mode on; backgroundCursorControl=\(backgroundCursorEnabled); "
                + "activationPolicy=accessory")
        }

        CFRunLoopRun()
        return 0
    }

    /// `run --once`: hide the cursor right now and report whether it took effect,
    /// so the tool can be verified without typing. Waits for the cursor to reappear
    /// (you moving the mouse) or a short timeout, then exits.
    private static func runOnce() -> Int32 {
        NSApplication.shared.setActivationPolicy(.accessory)
        if !BackgroundCursor.enable() {
            Log.warn("could not enable background cursor control; "
                + "the cursor may only hide while this process is frontmost")
        }

        NSCursor.setHiddenUntilMouseMoves(true)
        // Let the window server settle, then check whether it actually hid.
        CFRunLoopRunInMode(.defaultMode, 0.2, true)

        let canDetect: Bool
        switch BackgroundCursor.cursorIsVisible() {
        case .some(false):
            print("hide-the-cursor: cursor hidden ✅  Move the mouse to reveal it…")
            canDetect = true
        case .some(true):
            print("hide-the-cursor: the cursor did NOT hide. Run `hide-the-cursor doctor` "
                + "and check Accessibility permission.")
            return 1
        case .none:
            print("hide-the-cursor: hide requested (cursor visibility isn't reportable on "
                + "this macOS). Move the mouse; it should reveal.")
            canDetect = false
        }

        let timeout = canDetect ? 30.0 : 3.0
        var waited = 0.0
        while waited < timeout {
            CFRunLoopRunInMode(.defaultMode, 0.1, true)
            waited += 0.1
            if canDetect, BackgroundCursor.cursorIsVisible() == true {
                print("hide-the-cursor: cursor revealed on mouse movement — working as "
                    + "expected. ✅")
                return 0
            }
        }
        print("hide-the-cursor: done.")
        return 0
    }

    /// Load the config file for these options. Returns the (possibly empty) settings
    /// and the path it loaded from (nil if none was loaded).
    private static func loadConfig(_ options: RunOptions) -> (ConfigSettings, String?) {
        guard !options.noConfig else { return (.empty, nil) }
        let path = options.configPath ?? ConfigFile.defaultPath()
        if let loaded = ConfigFile.load(path: path) {
            return (loaded, path)
        } else if let explicit = options.configPath {
            Log.warn("config file not found at \(explicit)")
        }
        return (.empty, nil)
    }

    /// Resolve a mode + raw app tokens into a runtime filter and a human-readable
    /// summary. Logs how each app name resolved (and warns about ones that didn't).
    private static func buildFilter(
        mode: FilterMode, rawTokens: [String]
    ) -> (ResolvedFilter, String) {
        guard mode != .all, !rawTokens.isEmpty else {
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
private var reloadHandler: (() -> Void)?
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

    // SIGHUP reloads the config file in place (no restart).
    signal(SIGHUP, SIG_IGN)
    let hangup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
    hangup.setEventHandler { reloadHandler?() }
    hangup.resume()
    signalSources.append(hangup)
}
