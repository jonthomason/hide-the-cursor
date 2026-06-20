import AppKit

/// Frontmost application lookup. Thin wrapper around NSWorkspace so the rest of
/// the code reads cleanly.
public enum ActiveApp {
    /// The frontmost app's display name and bundle id in one lookup.
    public static func frontmost() -> (name: String?, bundleID: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName, app?.bundleIdentifier)
    }

    public static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    public static func frontmostName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
