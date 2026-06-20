import ApplicationServices
import CoreGraphics
import Foundation

/// `doctor` subcommand: checks whether an event tap can actually be created and,
/// if not, prints clear, actionable permission instructions.
public enum PermissionDoctor {
    @discardableResult
    public static func run() -> Int32 {
        print("hide-the-cursor doctor")
        print("")

        let trusted = AXIsProcessTrusted()
        print("Accessibility trusted:     \(trusted ? "yes" : "no")")

        let backgroundCursor = BackgroundCursor.enable()
        print("Background cursor control:  \(backgroundCursor ? "available ✅" : "unavailable ⚠️")")

        if canCreateEventTap() {
            print("Keyboard event tap:        can be created ✅")
            print("")
            print("Looks good. `hide-the-cursor run` should work.")
            return 0
        } else {
            print("Keyboard event tap:        cannot be created ❌")
            print("")
            printPermissionInstructions()
            return 1
        }
    }

    /// Attempt to create a throwaway listen-only tap and immediately tear it down.
    public static func canCreateEventTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, _, event, _ in
            Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }

    public static func printPermissionInstructions() {
        print("""
        Could not create the keyboard event tap. This is almost always a missing
        macOS permission for the process that launches hide-the-cursor.

        1. Open  System Settings → Privacy & Security → Accessibility
           Enable the app/binary that runs hide-the-cursor.

        2. If it still fails, also enable it under
           System Settings → Privacy & Security → Input Monitoring

        3. Quit and reopen that app (or `brew services restart hide-the-cursor`),
           then run `hide-the-cursor doctor` again.

        Note: macOS attaches these permissions to the *launching* process.
          • Running from a terminal?  Grant permission to that terminal app
            (e.g. Warp, Terminal, iTerm), not to hide-the-cursor.
          • Running via `brew services`? Grant permission to the hide-the-cursor
            binary itself (typically the Homebrew opt path).
        """)
    }
}
