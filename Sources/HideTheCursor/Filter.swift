/// How the app list is interpreted.
public enum FilterMode: Equatable {
    /// Act for every app.
    case all
    /// Act only for the listed apps (allowlist).
    case only
    /// Act for every app except the listed ones (blocklist).
    case except
}

/// Runtime decision about whether to act for a given frontmost app.
///
/// Holds both the canonical bundle ids resolved at startup *and* the raw,
/// lowercased tokens the user typed. Matching against either is forgiving: it
/// works whether the user gave an app name, a `.app` filename, or a bundle id,
/// and whether or not the app could be resolved to a bundle id at startup.
public struct ResolvedFilter: Equatable {
    public let mode: FilterMode
    let tokens: Set<String>
    let bundleIDs: Set<String>

    public init(mode: FilterMode, tokens: Set<String> = [], bundleIDs: Set<String> = []) {
        self.mode = mode
        self.tokens = tokens
        self.bundleIDs = bundleIDs
    }

    public static let all = ResolvedFilter(mode: .all)

    /// Should the cursor be hidden given this frontmost app?
    public func allows(bundleID: String?, name: String?) -> Bool {
        switch mode {
        case .all:
            return true
        case .only:
            return isListed(bundleID: bundleID, name: name)
        case .except:
            return !isListed(bundleID: bundleID, name: name)
        }
    }

    private func isListed(bundleID: String?, name: String?) -> Bool {
        if let bundleID {
            if bundleIDs.contains(bundleID) { return true }
            if tokens.contains(bundleID.lowercased()) { return true }
        }
        if let name, tokens.contains(name.lowercased()) { return true }
        return false
    }
}
