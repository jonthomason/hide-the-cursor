# Hide the Cursor

[![CI](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml/badge.svg)](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml)

A tiny macOS utility that **hides the mouse pointer while you type** and lets macOS
reveal it again as soon as you move the mouse — for the terminals (Warp, cmux, …) that
don't do it themselves.

## Quick start

Run it as an always-on background service with `brew services`. This section is all you
need.

**1. Install**

```sh
brew tap jonthomason/hide-the-cursor https://github.com/jonthomason/hide-the-cursor
brew install hide-the-cursor
```

**2. List the apps to hide the cursor in.** Create `~/.config/hide-the-cursor/config`,
one app per line (the name as it appears in your Applications folder):

```sh
mkdir -p ~/.config/hide-the-cursor
cat > ~/.config/hide-the-cursor/config <<'EOF'
Warp
iTerm
Ghostty
EOF
```

App names, `.app` filenames, and bundle ids all work. (Skip this file to hide the
cursor in *every* app instead.)

**3. Start it** — now, and automatically at every login:

```sh
brew services start hide-the-cursor
```

**4. Grant permission, once.** macOS requires the service to have Accessibility access.
Open **System Settings → Privacy & Security → Accessibility**, find **hide-the-cursor**
and switch it on. If it isn't listed, click **+**, press **⌘⇧G**, and paste this, then
enable it:

```
/opt/homebrew/opt/hide-the-cursor/bin/hide-the-cursor
```

Then apply it:

```sh
brew services restart hide-the-cursor
```

(Path shown is for Apple-silicon Macs; on Intel it's under `/usr/local`. Print yours
with `echo "$(brew --prefix)/opt/hide-the-cursor/bin/hide-the-cursor"`.)

**5. Use it.** Put the pointer over your terminal text and type — the cursor
disappears; move the mouse and it's back.

**Check that it's running:**

```sh
brew services list | grep hide-the-cursor
# hide-the-cursor   started   <you>   ~/Library/LaunchAgents/homebrew.mxcl.hide-the-cursor.plist
```

`started` means it's active and will relaunch at login. To confirm permissions and the
event tap are healthy, run `hide-the-cursor doctor`.

**Change which apps it covers:** edit `~/.config/hide-the-cursor/config`, then
`brew services restart hide-the-cursor`.

---

*Everything below is reference detail — the quick start above is all most people need.*

## Why it exists

macOS apps get "hide cursor while typing" for free *only if they implement it*.
Some terminals — notably **Warp** and **cmux** — don't, so a stationary pointer sits
on top of your text while you type. This tool fills that gap, system-wide or for a
chosen set of apps.

## The config file

`hide-the-cursor run` reads `~/.config/hide-the-cursor/config` if it exists. One
directive per line; blank lines and `#` comments are ignored:

```
# Apps to act on — name, .app filename, or bundle id, one per line.
# With apps listed and no "mode", they're an allowlist (only these).
Warp
iTerm

# mode except   # invert: hide everywhere EXCEPT the apps listed
# verbose       # log each key press
```

Use `--config <path>` to point at a different file, or `--no-config` to ignore it.
Command-line `--only`/`--except` override whatever the file says.

## Running directly (without the service)

You normally don't need this — the service is the intended way — but the same options
work on the command line:

```sh
hide-the-cursor run                       # all apps
hide-the-cursor run --only Warp --only iTerm
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

## Service details

The [Quick start](#quick-start) covers day-to-day service use. For the service
definition, log file locations, and managing it (`brew services list/restart/stop`),
see [HOMEBREW.md](HOMEBREW.md).

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
