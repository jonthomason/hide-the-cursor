# Hide the Cursor

[![CI](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml/badge.svg)](https://github.com/jonthomason/hide-the-cursor/actions/workflows/ci.yml)

A tiny macOS utility that **hides the mouse pointer while you type** and lets macOS
reveal it again as soon as you move the mouse — for the terminals (Warp, cmux, …) that
don't do it themselves.

## Quick start

Run it as an always-on background service with `brew services`.

**1. Install**

```sh
brew tap jonthomason/hide-the-cursor https://github.com/jonthomason/hide-the-cursor
brew install hide-the-cursor
```

**2. List the apps that need it** — the ones that don't hide the cursor on their own,
like Warp and cmux. Create `~/.config/hide-the-cursor/config`, one app per line (the
name as it appears in your Applications folder):

```sh
mkdir -p ~/.config/hide-the-cursor
cat > ~/.config/hide-the-cursor/config <<'EOF'
Warp
cmux
EOF
```

App names, `.app` filenames, and bundle ids all work. (Skip this file to hide the
cursor in *every* app instead.)

**3. Start it** — now, and automatically at every login:

```sh
brew services start hide-the-cursor
```

**4. Grant permission, once.** macOS requires the service to have **Input Monitoring**
access (older macOS versions use Accessibility instead). Open **System Settings →
Privacy & Security → Input Monitoring**, find **hide-the-cursor** and switch it on. If
it isn't listed, click **+**, press **⌘⇧G**, and paste this, then enable it:

```
/opt/homebrew/opt/hide-the-cursor/bin/hide-the-cursor
```

Then apply it:

```sh
brew services restart hide-the-cursor
```

(Path shown is for Apple-silicon Macs; on Intel it's under `/usr/local`. Print yours
with `echo "$(brew --prefix)/opt/hide-the-cursor/bin/hide-the-cursor"`.)

**5. Check it works.** Run `hide-the-cursor run --once` — it hides the cursor right
away and prints `cursor hidden ✅` (move the mouse and it returns), so you can confirm
the setup without waiting to type. In normal use, just type in your terminal; the
cursor hides while you do and returns when you move the mouse.

**Check that it's running:**

```sh
brew services list | grep hide-the-cursor
# hide-the-cursor   started   <you>   ~/Library/LaunchAgents/homebrew.mxcl.hide-the-cursor.plist
```

`started` means it's active and will relaunch at login. To confirm permissions and the
event tap are healthy, run `hide-the-cursor doctor`.

**Change which apps it covers:** edit `~/.config/hide-the-cursor/config`, then
`brew services restart hide-the-cursor` (or `pkill -HUP -f hide-the-cursor` to reload
in place).

## Why it exists

Some terminals — notably **Warp** and **cmux** — don't hide the cursor while you type,
so a stationary pointer sits on your text. This fills that gap.

## The config file

`run` reads `~/.config/hide-the-cursor/config` if present — one app per line (name,
`.app` filename, or bundle id), `#` comments ignored:

```
Warp
cmux
# mode except   # invert: hide everywhere EXCEPT these
# verbose       # log each key press
```

`--config <path>` points elsewhere, `--no-config` ignores it, and `--only`/`--except`
override it. Send the running daemon `SIGHUP` (`pkill -HUP -f hide-the-cursor`) to
reload the file without restarting.

## Commands

| Command | What it does |
| --- | --- |
| `run [--only <app> …]` | Hide the cursor, only for these apps. |
| `run [--except <app> …]` | Hide the cursor for all apps except these. |
| `run … --verbose` | Log each key press, for debugging. |
| `run --once` | Hide the cursor once now, as a self-test (no typing needed). |
| `list` | Show which apps cursor-hiding is enabled for (config file or flags). |
| `list-app` | Print the frontmost app's name and bundle id. |
| `resolve <app> …` | Show the bundle id an app name resolves to. |
| `doctor` | Check permissions and the event tap. |
| `help`, `version` | The usual. |

`<app>` accepts an app name, `.app` filename, or bundle id. Names are resolved at
startup and also matched by display name at runtime, so apps whose filename differs
from their display name (iTerm.app → "iTerm2", Visual Studio Code.app → "Code") work
either way. Check one with `resolve Warp iTerm`. Running directly works too —
`hide-the-cursor run --only Warp`, stop with `Ctrl-C`.

## How it works

A **listen-only** CoreGraphics tap watches global `keyDown` events (never modifying or
consuming them) and calls `NSCursor.setHiddenUntilMouseMoves(true)` on each matching
press; macOS hides the cursor and reveals it on the next mouse move. Since the tool
isn't frontmost, it registers as an accessory app and opts into background cursor
control so the hide actually takes effect.

## Permissions & troubleshooting

The event tap needs **Input Monitoring** permission (older macOS versions use
Accessibility) for the **launching** process — your terminal when run directly, or the
binary itself when run as a service ([Quick start](#quick-start) step 4).
`hide-the-cursor doctor` checks it, and `hide-the-cursor run --once` hides the cursor
immediately so you can confirm it works without typing.

If the cursor won't hide, run `hide-the-cursor run --only Warp --verbose` and read the
per-keypress log:

- **No `keyDown` lines** → no permission (grant it, above).
- **`matched=false`** → frontmost isn't your target; check the `frontmost=` value.
- **`matched=true cursorVisibleAfter=true`** → the hide isn't sticking; `doctor` says
  if background cursor control failed.

For service management and logs, see [HOMEBREW.md](HOMEBREW.md).

## Building from source

```sh
swift build -c release   # binary at .build/release/hide-the-cursor
swift test
```

## Project layout

```
Sources/hide-the-cursor/     all the Swift sources (CLI, filter, resolver, event tap, main)
Tests/hide-the-cursor-tests/ unit tests
Formula/hide-the-cursor.rb   Homebrew formula
```

## Contributing & license

See [CONTRIBUTING.md](CONTRIBUTING.md). BSD 2-Clause — see [LICENSE](LICENSE).
