# Publishing the Homebrew formula

`logsentry.rb` is the formula. Homebrew does not install it from this repository — it installs it
from a **tap**, which is just a separate GitHub repo whose name starts with `homebrew-`.

## One-time setup

1. Tag and push a release, because the formula installs from a release tarball:

   ```bash
   git tag -a v1.5.0 -m "LogSentry v1.5.0"
   git push origin v1.5.0
   ```

2. Get the checksum of the tarball GitHub generates for that tag:

   ```bash
   curl -sL https://github.com/dhananjay2403/logsentry-unix-cli/archive/refs/tags/v1.5.0.tar.gz \
     | shasum -a 256
   ```

3. Paste that value into `logsentry.rb`, replacing `REPLACE_WITH_SHA256_OF_THE_RELEASE_TARBALL`.

4. Create a public repo named **`homebrew-tap`** under your account, and put the formula in it:

   ```bash
   git clone https://github.com/dhananjay2403/homebrew-tap.git
   cd homebrew-tap
   mkdir -p Formula
   cp /path/to/logsentry-unix-cli/packaging/logsentry.rb Formula/
   git add Formula/logsentry.rb
   git commit -m "logsentry 1.5.0"
   git push
   ```

Users can then install with:

```bash
brew tap dhananjay2403/tap
brew install logsentry
```

(`brew tap dhananjay2403/tap` resolves to the `homebrew-tap` repo — the prefix is implied.)

## Verifying the formula before publishing

```bash
brew install --build-from-source ./logsentry.rb   # installs from this local file
brew test logsentry                               # runs the `test do` block
brew audit --strict --new logsentry               # style and correctness checks
brew uninstall logsentry
```

`brew audit` is what catches the conventions that are easy to get wrong: description phrasing
(no leading article, no repetition of the name), license identifier, and formula naming.

## Releasing a new version

1. Bump `VERSION` in `logsentry`, update `CHANGELOG.md`, tag, and push.
2. Recompute the `sha256` for the new tarball.
3. Update `url` and `sha256` in the tap's `Formula/logsentry.rb` and push.

Keep the copy in this repository in sync so the formula is reviewable alongside the code.
