# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-06-25

### Added
- `reload-config` command: tells the running daemon to re-read its config (it sends
  SIGHUP to the `hide-the-cursor` process), so config edits apply without a
  `brew services restart` — which avoids macOS re-prompting for Input Monitoring. The
  daemon's startup line and help now point at this command.

### Changed
- LICENSE copyright line is no longer personalized (standard BSD 2-Clause).

## [0.4.0] - 2026-06-25

### Added
- `list` command: prints which apps cursor-hiding is enabled for (resolved to bundle
  ids), from the config file or from `--only`/`--except`/`--config` flags.

## [0.3.1] - 2026-06-20

### Changed
- Permission docs now lead with **Input Monitoring** (what current macOS requires for
  the event tap); Accessibility is noted as the older-macOS fallback. Updated the
  README quick start, `doctor` instructions, HOMEBREW.md, and the formula caveats.
- Quick start now uses `run --once` as the "check it works" step.
- `doctor` drops the (misleading on current macOS) "Accessibility trusted" line; the
  event-tap-creation check remains the source of truth.

### Docs
- Note that ad-hoc signing means each `brew upgrade` can leave a stale permission
  entry; remove old ones with the **–** button.

## [0.3.0] - 2026-06-20

### Added
- `run --once`: a self-test that hides the cursor immediately and reports whether it
  took effect, so you can verify the tool without typing.
- **SIGHUP reloads the config file in place** — edit `~/.config/hide-the-cursor/config`
  and `pkill -HUP -f hide-the-cursor` instead of restarting the service.

### Changed
- In "all apps" mode the per-key-press hot path no longer looks up the frontmost app
  (it's irrelevant there) — a touch less work per keystroke.

## [0.2.1] - 2026-06-20

### Changed
- Consolidated the library + executable split into a single `hide-the-cursor` target
  (`Sources/hide-the-cursor/`); tests in `Tests/hide-the-cursor-tests/`. No behavior
  change — just a cleaner, single-named source layout.
- Extracted command-line/config precedence into a pure `SettingsResolver` with unit
  tests.

## [0.2.0] - 2026-06-20

### Added
- Config file at `~/.config/hide-the-cursor/config` (one app per line; `mode except`
  and `verbose` directives), so the `brew services` daemon can be configured without
  editing the service definition. `--config <path>` and `--no-config` override it;
  command-line `--only`/`--except` take precedence over the file.

### Changed
- `run` logs the config path it loaded and warns if a `--config` file is missing.

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

[0.5.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.5.0
[0.4.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.4.0
[0.3.1]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.3.1
[0.3.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.3.0
[0.2.1]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.2.1
[0.2.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.2.0
[0.1.0]: https://github.com/jonthomason/hide-the-cursor/releases/tag/v0.1.0
