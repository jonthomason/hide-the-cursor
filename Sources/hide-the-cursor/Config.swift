import Foundation

/// Settings parsed from a config file. Lets the `brew services` daemon be
/// configured by editing a file instead of the service definition.
public struct ConfigSettings: Equatable {
    public var mode: FilterMode
    public var apps: [String]
    public var verbose: Bool

    public init(mode: FilterMode = .all, apps: [String] = [], verbose: Bool = false) {
        self.mode = mode
        self.apps = apps
        self.verbose = verbose
    }

    public static let empty = ConfigSettings()
}

/// Reads and parses the config file.
///
/// Format (one directive per line; blank lines and `#` comments ignored):
///
///     # apps to act on — name, .app filename, or bundle id, one per line
///     Warp
///     iTerm
///     mode except      # optional: treat the list as a blocklist instead
///     verbose          # optional: log each key press
///
/// With apps listed and no `mode`, the list is an allowlist (`only`).
public enum ConfigFile {
    public static func parse(_ contents: String) -> ConfigSettings {
        var mode: FilterMode?
        var apps: [String] = []
        var verbose = false

        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            line = stripInlineComment(line)
            if line.isEmpty { continue }

            let lower = line.lowercased()
            if lower == "verbose" {
                verbose = true
            } else if lower.hasPrefix("mode ") {
                let value = line.dropFirst(5).trimmingCharacters(in: .whitespaces).lowercased()
                if value == "only" { mode = .only }
                else if value == "except" { mode = .except }
                else if value == "all" { mode = .all }
            } else {
                apps.append(line)
            }
        }

        let resolvedMode = mode ?? (apps.isEmpty ? .all : .only)
        return ConfigSettings(mode: resolvedMode, apps: apps, verbose: verbose)
    }

    /// Default config path: `$XDG_CONFIG_HOME/hide-the-cursor/config`, else
    /// `~/.config/hide-the-cursor/config`. Works for both manual runs and the
    /// `brew services` user agent (which has the user's HOME set).
    public static func defaultPath() -> String {
        let environment = ProcessInfo.processInfo.environment
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return "\(xdg)/hide-the-cursor/config"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/hide-the-cursor/config"
    }

    /// Returns nil if the file does not exist or can't be read.
    public static func load(path: String) -> ConfigSettings? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return parse(contents)
    }

    /// Strip a trailing ` # comment` (only when the `#` follows whitespace, so an
    /// app token containing `#` is left intact).
    private static func stripInlineComment(_ line: String) -> String {
        guard let hash = line.firstIndex(of: "#") else { return line }
        let before = line[..<hash]
        guard before.last?.isWhitespace == true else { return line }
        return String(before).trimmingCharacters(in: .whitespaces)
    }
}
