# Hide the Cursor

[![CI](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml/badge.svg)](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml)

A tiny macOS command-line utility that **hides the mouse pointer while you type** and
lets macOS reveal it again automatically as soon as you move the mouse.

No menu bar app, no UI, no app bundle — just a CLI you run, or run as a background
service via `brew services`.

## Why it exists

macOS apps get "hide cursor while typing" for free *only if they implement it*.
Some terminals — notably **Warp** and **cmux** — don't, so a stationary pointer sits
on top of your text while you type. This tool fills that gap, system-wide or for a
chosen set of apps.

## Install

From this repo's Homebrew tap:

```sh
brew tap jonthomason/hide-the-cursor https://github.com/jonthomason/hide-the-cursor
brew install hide-the-cursor
```

Or track the latest `main`:

```sh
brew install --HEAD jonthomason/hide-the-cursor/hide-the-cursor
```

(See [Building from source](#building-from-source) if you'd rather not use Homebrew.
A future goal is submission to homebrew-core so a plain `brew install hide-the-cursor`
works without the tap.)

## Quick start

Hide the cursor while typing in **any** app:

```sh
hide-the-cursor run
```

Only for specific apps — give an **app name**, a `.app` filename, or a bundle id;
they're interchangeable:

```sh
hide-the-cursor run --only Warp
hide-the-cursor run --only Warp --only iTerm
hide-the-cursor run --only dev.warp.Warp-Stable
```

Or everywhere *except* certain apps:

```sh
hide-the-cursor run --except "Visual Studio Code"
```

Stop it with `Ctrl-C` (or `SIGTERM`); it disables the tap cleanly on the way out.

## Commands

| Command | What it does |
| --- | --- |
| `run [--only <app> …]` | Hide the cursor on each key press, only for these apps. |
| `run [--except <app> …]` | Hide the cursor for all apps except these. |
| `run … --verbose` | Log each key press (frontmost app, whether it matched, cursor state). |
| `list-app` | Print the frontmost app's name and bundle id (+ a ready-to-paste `--only`). |
| `resolve <app> …` | Show the bundle id each app name resolves to. |
| `doctor` | Check permissions and that the event tap can be created. |
| `help`, `version` | The usual. |

`--only` and `--except` are mutually exclusive. `<app>` accepts app names ("Warp"),
`.app` filenames, or bundle ids — see [App names vs. bundle ids](#app-names-vs-bundle-ids).

## App names vs. bundle ids

You don't need to hunt down bundle ids. `--only`/`--except` accept whichever is
convenient:

- An **app name** as it appears in `/Applications` — `--only Warp`
- A **`.app` filename** — `--only "Visual Studio Code"`
- A **bundle id** — `--only dev.warp.Warp-Stable`

At startup each name is resolved to its bundle id, and at runtime the frontmost app's
display name is also matched directly. That dual matching transparently handles the
apps whose filename differs from their display name (e.g. `iTerm.app` shows as
"iTerm2", `Visual Studio Code.app` shows as "Code") — either spelling works.

Not sure what something resolves to? Ask:

```sh
$ hide-the-cursor resolve Warp iTerm "Visual Studio Code"
Warp -> dev.warp.Warp-Stable
iTerm -> com.googlecode.iterm2
Visual Studio Code -> com.microsoft.VSCode
```

Or focus an app and run `hide-the-cursor list-app`.

## How it works

- A **listen-only** CoreGraphics event tap observes global `keyDown` events. It never
  modifies, consumes, or remaps keys — it observes and returns each event unchanged.
- On each matching key press it calls AppKit's
  `NSCursor.setHiddenUntilMouseMoves(true)`. macOS does the actual hiding and reveals
  the cursor on the next mouse movement. The call is idempotent-ish: every key press
  just re-requests "stay hidden until the mouse moves" — there's no toggle to get out
  of sync.
- Because the tool runs in the background (your terminal stays frontmost), it
  registers as an invisible accessory app and opts into background cursor control via
  CoreGraphics, so the hide actually takes effect from a non-foreground process.

## Required macOS permissions

The event tap needs permission for the process that **launches** hide-the-cursor:

- **System Settings → Privacy & Security → Accessibility**
- If that isn't enough, also **Privacy & Security → Input Monitoring**

macOS attaches the permission to the launching process, not to this tool:

- Running it from a terminal? Grant permission to **that terminal app** (Warp,
  Terminal, iTerm, …).
- Running it via `brew services`? Grant permission to the **hide-the-cursor binary**
  itself (the Homebrew `opt` path).

After granting permission, restart the command (or
`brew services restart hide-the-cursor`). Check everything at once:

```sh
hide-the-cursor doctor
```

## Run it as a background service

The intended way to run this day-to-day is as a Homebrew service so it starts at
login and stays alive:

```sh
brew services start hide-the-cursor
```

See [HOMEBREW.md](HOMEBREW.md) for the service definition, how to scope it to specific
apps, and the one extra permission step the service needs.

## Troubleshooting

If the cursor doesn't hide, run with `--verbose` to see what happens on each key press:

```sh
hide-the-cursor run --only Warp --verbose
```

```
htc-debug: keyDown #1 frontmost=Warp/dev.warp.Warp-Stable matched=true cursorVisibleAfter=false
```

- **No `keyDown` lines at all** → events aren't reaching the tap. Grant Accessibility
  (and possibly Input Monitoring) permission; see above.
- **`matched=false`** → the frontmost app isn't the one you targeted. Check the
  `frontmost=` value (or run `list-app`) and adjust your `--only`.
- **`matched=true` but `cursorVisibleAfter=true`** → the hide isn't taking effect.
  hide-the-cursor enables background cursor control automatically; if it couldn't, it
  logs a warning on startup and `doctor` reports it.

## Building from source

Requires Swift (Xcode or the Swift toolchain).

```sh
swift build -c release       # binary at .build/release/hide-the-cursor
swift test                   # run the unit tests
.build/release/hide-the-cursor run --only Warp
```

## Project layout

```
Package.swift
Sources/
  HideTheCursor/        # library (unit-testable core)
    CLI.swift           # argument parsing
    Filter.swift        # all / only / except matching
    AppResolver.swift   # app name / .app / bundle id -> bundle id
    ActiveApp.swift     # frontmost app lookup
    EventTapManager.swift
    BackgroundCursor.swift  # opt into background cursor control
    PermissionDoctor.swift
    Runner.swift        # command dispatch + run loop + signal handling
    Log.swift
  hide-the-cursor/
    main.swift          # thin executable entry point
Tests/
  HideTheCursorTests/   # parser, filter, and resolver tests
Formula/
  hide-the-cursor.rb    # Homebrew formula
```

(The core lives in a library target so it can be unit-tested; the executable is a thin
wrapper.)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs welcome.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
