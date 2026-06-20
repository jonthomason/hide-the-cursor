import CoreFoundation
import Foundation

/// Allows this process to change the system cursor even when it is **not** the
/// frontmost application.
///
/// By default macOS only honors cursor show/hide requests from the foreground
/// app. Since hide-the-cursor is a background helper (the terminal stays
/// frontmost), we must opt into background cursor control. This is done by
/// setting the `SetsCursorInBackground` property on our CoreGraphics connection.
///
/// `CGSMainConnectionID` / `CGSSetConnectionProperty` are private CoreGraphics
/// SPI. They have been stable for many macOS releases and are widely used by
/// cursor utilities, but they are not part of the public SDK, so we resolve them
/// at runtime with `dlsym` rather than linking them directly.
enum BackgroundCursor {
    private typealias MainConnectionIDFn = @convention(c) () -> Int32
    private typealias SetConnectionPropertyFn =
        @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    /// Returns true if background cursor control was successfully enabled.
    @discardableResult
    static func enable() -> Bool {
        guard
            let mainConnectionID = lookup("CGSMainConnectionID", as: MainConnectionIDFn.self),
            let setConnectionProperty =
                lookup("CGSSetConnectionProperty", as: SetConnectionPropertyFn.self),
            let trueValue = kCFBooleanTrue
        else {
            return false
        }

        let connection = mainConnectionID()
        let status = setConnectionProperty(
            connection, connection, "SetsCursorInBackground" as CFString, trueValue)
        return status == 0
    }

    private typealias CursorIsVisibleFn = @convention(c) () -> Int32

    /// Best-effort read of global cursor visibility, for `--verbose` diagnostics.
    /// `CGCursorIsVisible` is marked unavailable in the current SDK, but the symbol
    /// is still present at runtime, so we resolve it with dlsym. Returns nil if it
    /// can't be found.
    static func cursorIsVisible() -> Bool? {
        guard let cursorIsVisible = lookup("CGCursorIsVisible", as: CursorIsVisibleFn.self) else {
            return nil
        }
        return cursorIsVisible() != 0
    }

    private static func lookup<T>(_ symbolName: String, as _: T.Type) -> T? {
        // RTLD_DEFAULT == (void *)-2 on Darwin: search every loaded image.
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = dlsym(rtldDefault, symbolName) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
