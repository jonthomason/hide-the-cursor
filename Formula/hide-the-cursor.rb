# Homebrew formula for hide-the-cursor.
#
# Install from this repo's tap:
#   brew tap jonthomason/hide-the-cursor https://github.com/jonthomason/hide-the-cursor
#   brew install hide-the-cursor
#   brew services start hide-the-cursor
class HideTheCursor < Formula
  desc "Hide the macOS mouse cursor while typing"
  homepage "https://github.com/jonthomason/hide-the-cursor"
  url "https://github.com/jonthomason/hide-the-cursor/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
  license "BSD-2-Clause"
  head "https://github.com/jonthomason/hide-the-cursor.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    # --disable-sandbox: Homebrew's build sandbox blocks SwiftPM's caches.
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/hide-the-cursor"
  end

  service do
    run [opt_bin/"hide-the-cursor", "run"]
    keep_alive true
    process_type :interactive
    log_path var/"log/hide-the-cursor.log"
    error_log_path var/"log/hide-the-cursor.err.log"
  end

  def caveats
    <<~EOS
      hide-the-cursor needs permission for the launching process to observe key
      events. When run as a service, grant permission to the binary itself:

        #{opt_bin}/hide-the-cursor

      Add it under System Settings -> Privacy & Security -> Accessibility
      (and, if needed, Input Monitoring), then:

        brew services restart hide-the-cursor

      To scope it to specific apps, edit the service to pass --only, e.g.
      `--only Warp`. See HOMEBREW.md. Verify anytime with:

        #{opt_bin}/hide-the-cursor doctor
    EOS
  end

  test do
    assert_match "hide-the-cursor #{version}", shell_output("#{bin}/hide-the-cursor version")
    assert_match "com.apple.Terminal", shell_output("#{bin}/hide-the-cursor resolve Terminal")
  end
end
