import Foundation

// Line-buffer stdout so logs flush promptly when redirected to a file
// (e.g. running under `brew services`, where stdout is not a TTY).
setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())

let command: Command
do {
    command = try CLI.parse(arguments)
} catch {
    FileHandle.standardError.write(Data("hide-the-cursor: \(error)\n\n".utf8))
    Runner.printUsage()
    exit(2)
}

exit(Runner.run(command))
