import Foundation

/// Minimal stderr logging. We write to stderr directly (not `print`) so messages
/// are unbuffered and never interleave oddly with stdout.
enum Log {
    static func warn(_ message: String) {
        write("hide-the-cursor: \(message)")
    }

    static func debug(_ message: String) {
        write("htc-debug: \(message)")
    }

    private static func write(_ line: String) {
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }
}
