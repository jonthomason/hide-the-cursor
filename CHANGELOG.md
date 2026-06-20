# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-20

First public release.

### Added
- `run` command: hides the cursor on each key press via a listen-only CoreGraphics
  event tap and `NSCursor.setHiddenUntilMouseMoves(true)`. The tap never modifies or
  consumes key events.
- `--only` / `--except` filters accepting **app names**, `.app` filenames, or bundle
  ids interchangeably, resolved at startup and matched by display name at runtime.
- `list-app` — print the frontmost app's name and bundle id.
- `resolve` — show the bundle id an app name resolves to.
- `doctor` — check Accessibility, background cursor control, and event-tap creation,
  with permission guidance.
- `--verbose` diagnostics logging each key press.
- Background cursor control (accessory `NSApplication` + `SetsCursorInBackground`) so
  the hide works from a non-foreground process.
- Clean shutdown on SIGINT/SIGTERM.
- Homebrew formula with a `brew services` definition.

[0.1.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.1.0
