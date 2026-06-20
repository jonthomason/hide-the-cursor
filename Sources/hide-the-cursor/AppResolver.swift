import AppKit
import Foundation

/// Resolves a user-friendly token — an app name ("Warp"), a bundle filename
/// ("Warp.app"), or a bundle id ("dev.warp.Warp-Stable") — to a bundle
/// identifier, so the command line never *requires* bundle ids.
public enum AppResolver {
    /// Returns the bundle identifier for `token`, or nil if no installed app
    /// matches it.
    public static func resolveBundleID(_ token: String) -> String? {
        // 1. Already a valid, installed bundle id?
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: token) != nil {
            return token
        }
        // 2. An installed app located by name / ".app" filename?
        if let url = applicationURL(forName: token),
           let identifier = Bundle(url: url)?.bundleIdentifier {
            return identifier
        }
        // 3. A currently-running app whose display name matches?
        let lowered = token.lowercased()
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == lowered
        }) {
            return running.bundleIdentifier
        }
        return nil
    }

    /// Locate an installed "<name>.app" in the standard application directories.
    private static func applicationURL(forName token: String) -> URL? {
        let name = token.hasSuffix(".app") ? String(token.dropLast(4)) : token
        let fileManager = FileManager.default
        for directory in searchDirectories {
            let candidate = directory.appendingPathComponent("\(name).app")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static var searchDirectories: [URL] {
        var directories = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
        ].map { URL(fileURLWithPath: $0) }
        directories.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications"))
        return directories
    }
}
