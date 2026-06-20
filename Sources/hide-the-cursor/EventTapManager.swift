import AppKit
import CoreGraphics
import Foundation

/// Observes global keyDown events with a *listen-only* CoreGraphics event tap and,
/// on each key press, asks macOS to hide the cursor until the mouse moves.
///
/// The tap never modifies or consumes events: it observes and returns them
/// unchanged. We do not draw or hide the cursor ourselves — we only call
/// `NSCursor.setHiddenUntilMouseMoves(true)`, which is idempotent-ish and lets
/// macOS reveal the cursor again on the next mouse movement.
public final class EventTapManager {
    // Mutable so the filter can be swapped on a config reload (SIGHUP). Only ever
    // touched on the main thread (both the keyDown callback and the reload run
    // there), so no locking is needed.
    private var filter: ResolvedFilter
    private var verbose: Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDownCount = 0

    /// - Parameters:
    ///   - filter: which frontmost apps to act on.
    ///   - verbose: log each keyDown (frontmost app, match, cursor visibility).
    public init(filter: ResolvedFilter, verbose: Bool = false) {
        self.filter = filter
        self.verbose = verbose
    }

    /// Swap the active filter (and verbosity) — used when the config is reloaded.
    /// Must be called on the main thread.
    public func update(filter: ResolvedFilter, verbose: Bool) {
        self.filter = filter
        self.verbose = verbose
    }

    /// Creates and enables the event tap on the current run loop.
    /// Returns `false` if the tap could not be created — almost always a missing
    /// macOS permission (Accessibility / Input Monitoring).
    @discardableResult
    public func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // C-compatible callback: no captures. `self` is passed through `userInfo`.
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handle(type: type, event: event)
            }
            // Listen-only tap: the return value is ignored, but we hand the
            // original event straight back to be explicit and safe.
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    /// Disable and tear down the tap. Safe to call more than once.
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            keyDownCount += 1
            // In "all apps" mode the frontmost app is irrelevant, so skip the
            // lookup entirely — the hot path becomes a single AppKit call. (We
            // still look it up under --verbose so the log stays useful.)
            let app: (name: String?, bundleID: String?) =
                (filter.mode != .all || verbose) ? ActiveApp.frontmost() : (nil, nil)
            let matched = filter.allows(bundleID: app.bundleID, name: app.name)
            if matched {
                NSCursor.setHiddenUntilMouseMoves(true)
            }
            if verbose {
                let visibility = BackgroundCursor.cursorIsVisible().map { "\($0)" } ?? "unknown"
                Log.debug("keyDown #\(keyDownCount) "
                    + "frontmost=\(app.name ?? "(none)")/\(app.bundleID ?? "(none)") "
                    + "matched=\(matched) cursorVisibleAfter=\(visibility)")
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system can disable a tap (e.g. it was too slow). Re-enable it.
            if let tap = eventTap {
                Log.warn("event tap was disabled by the system, re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        default:
            break
        }
    }
}
