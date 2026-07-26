# Homebrew formula for LogSentry.
#
# This file lives here for reference; Homebrew installs it from a tap
# repository. See packaging/README.md for how to publish it.
class Logsentry < Formula
  desc "Bash CLI for Unix log analysis, reporting, and compressed backups"
  homepage "https://github.com/dhananjay2403/logsentry-unix-cli"
  url "https://github.com/dhananjay2403/logsentry-unix-cli/archive/refs/tags/v1.5.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256_OF_THE_RELEASE_TARBALL"
  license "MIT"
  head "https://github.com/dhananjay2403/logsentry-unix-cli.git", branch: "main"

  def install
    bin.install "logsentry"
  end

  test do
    assert_match "logsentry", shell_output("#{bin}/logsentry --version")

    (testpath/"logs/app.log").write <<~EOS
      2026-03-01 10:00:00 INFO service started
      2026-03-01 10:00:01 ERROR connection refused
      2026-03-01 10:00:02 WARNING high latency
    EOS

    output = shell_output("#{bin}/logsentry --json #{testpath}/logs")
    assert_match '"errors": 1', output
    assert_match '"warnings": 1', output
  end
end
