/// The effective run configuration after merging command-line options with the
/// config file. Resolution of app names to bundle ids happens separately, later.
struct EffectiveSettings: Equatable {
    var mode: FilterMode
    var apps: [String]
    var verbose: Bool
}

/// Combines `RunOptions` (command line) with `ConfigSettings` (file). Pure, so the
/// precedence rules are unit-tested.
///
/// Precedence:
///  - `--only` wins over everything; else `--except` wins; else the config file's
///    apps/mode; else "all apps".
///  - `--verbose` is additive with the file's `verbose`.
enum SettingsResolver {
    static func resolve(options: RunOptions, config: ConfigSettings) -> EffectiveSettings {
        let verbose = options.verbose || config.verbose

        if !options.only.isEmpty {
            return EffectiveSettings(mode: .only, apps: options.only, verbose: verbose)
        }
        if !options.except.isEmpty {
            return EffectiveSettings(mode: .except, apps: options.except, verbose: verbose)
        }
        return EffectiveSettings(mode: config.mode, apps: config.apps, verbose: verbose)
    }
}
