# Contributing

Thanks for your interest in hide-the-cursor. It's intentionally small — please keep
changes boring, readable, and dependency-free.

## Development

```sh
swift build          # debug build
swift test           # run the unit tests
swift build -c release
```

Requires macOS and a Swift toolchain (Xcode or the standalone toolchain).

## Guidelines

- **No third-party dependencies.** The argument parser is hand-rolled on purpose.
- **Don't consume or modify key events.** The event tap stays listen-only and returns
  every event unchanged.
- **Keep parsing pure and tested.** Argument and filter logic live in the
  `HideTheCursor` library target with unit tests; the executable target is a thin
  wrapper. Add tests for new flags and matching behavior.
- **Match the surrounding style.** Small types, clear names, comments only where the
  *why* isn't obvious.

## Pull requests

- Run `swift test` and `swift build -c release` before opening a PR; CI runs both.
- Describe the user-visible behavior change and how you verified it (including the
  manual cursor check if relevant — automated tests can't see the cursor).
- Update `README.md` / `CHANGELOG.md` when behavior changes.

## Manual functional check

Automated tests can't observe the real cursor, so for cursor-affecting changes:

1. `swift build -c release`
2. Focus a terminal that doesn't hide its own cursor (e.g. Warp).
3. `.build/release/hide-the-cursor run --only Warp`
4. Put the pointer over the terminal text, type — the cursor should vanish.
5. Move the mouse — it should reappear.
