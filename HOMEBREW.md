# Homebrew distribution & service

`hide-the-cursor` is meant to be installed via Homebrew and run as a background
service via `brew services`. This document covers the formula, the service, and the
one permission gotcha specific to running it as a daemon.

## Install

From this repo's tap:

```sh
brew tap jonthomason/hide-the-cursor https://github.com/jonthomason/hide-the-cursor
brew install hide-the-cursor
```

## The formula

[`Formula/hide-the-cursor.rb`](Formula/hide-the-cursor.rb) builds from source with
SwiftPM and installs the single binary:

```ruby
def install
  system "swift", "build", "--disable-sandbox", "-c", "release"
  bin.install ".build/release/hide-the-cursor"
end
```

`--disable-sandbox` is required because Homebrew's build sandbox blocks the SwiftPM
package cache.

## The service block

```ruby
service do
  run [opt_bin/"hide-the-cursor", "run"]
  keep_alive true
  process_type :interactive
  log_path var/"log/hide-the-cursor.log"
  error_log_path var/"log/hide-the-cursor.err.log"
end
```

- `process_type :interactive` matters: the daemon interacts with the GUI login
  session (the cursor), so it must run interactively, not as a background batch job.
- `keep_alive true` restarts it if it exits.
- The binary line-buffers stdout, so the log files fill in promptly.

## Scoping the service to specific apps

The service runs `hide-the-cursor run`, which reads `~/.config/hide-the-cursor/config`.
List the apps there (one per line — name, `.app` filename, or bundle id):

```sh
mkdir -p ~/.config/hide-the-cursor
cat > ~/.config/hide-the-cursor/config <<'EOF'
Warp
iTerm
EOF
brew services restart hide-the-cursor
```

No config file means "all apps". To invert the list (hide everywhere *except* the
listed apps), put `mode except` on its own line. See the README's
[config file](README.md#the-config-file) section for the full format.

Instead of a full restart, you can reload the config in place by sending the daemon
`SIGHUP`:

```sh
pkill -HUP -f hide-the-cursor
```

You can also bake a fixed scope into the formula's service args instead
(`run [..., "--only", "Warp"]`), but the config file is preferred — it survives
upgrades and doesn't need a `brew reinstall`.

## Managing the service

```sh
brew services start hide-the-cursor
brew services list
brew services restart hide-the-cursor
brew services stop hide-the-cursor
```

Logs:

```sh
tail -f "$(brew --prefix)/var/log/hide-the-cursor.log"
tail -f "$(brew --prefix)/var/log/hide-the-cursor.err.log"
```

## The permission gotcha (read this)

The event tap needs Accessibility / Input Monitoring permission for the process that
**launches** it. From a terminal, that's the terminal app. But when `brew services`
launches it, the launching process is **the hide-the-cursor binary itself**, so grant
permission to:

```
$(brew --prefix)/opt/hide-the-cursor/bin/hide-the-cursor
```

Steps:

1. `brew services start hide-the-cursor`
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Add the binary above (use the `opt` path — it's stable across upgrades). If the tap
   still can't be created, also add it under **Input Monitoring**.
4. `brew services restart hide-the-cursor`
5. Confirm:

   ```sh
   "$(brew --prefix)/opt/hide-the-cursor/bin/hide-the-cursor" doctor
   ```

If `doctor` reports the tap can be created, the service can hide your cursor.

## Local dry run before publishing a release

Exercise the build-and-install path locally against the formula:

```sh
brew install --build-from-source --HEAD ./Formula/hide-the-cursor.rb
```
