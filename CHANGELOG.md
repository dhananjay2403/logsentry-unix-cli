# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-07-26

Analysis engine rewrite and a set of additive flags. Existing invocations
(`logsentry`, `logsentry <dir>`, `-d`, `-t N`, `--top-errors=N`, `-h`, and the
`LOG_DIR` / `REPORT_DIR` / `BACKUP_ROOT` variables) behave exactly as before,
including the automatic backup on every run.

### Added

- `--json` — machine-readable summary with per-file results, for pipelines and `jq`.
- `--fail-on-error N` — exit status `2` once errors reach N, so the tool can gate CI.
- `-r`, `--recursive` and `--pattern GLOB` — analyse nested directories and rotated
  files such as `app.log.1`.
- `--quiet` — totals only.
- `--no-color`, plus support for the `NO_COLOR` environment convention.
- `--keep N` — keep only the N newest backup archives.
- Backups now report raw size, archive size, and the compression ratio.
- Reports include a per-file table and the total number of lines analysed.

### Changed

- Analysis now makes a **single pass per file** with a POSIX `awk` program instead of
  two to four `grep` / `sort` / `uniq` / `wc` passes.
- Log levels are matched as **whole words**. `error_rate=0`, `ErrorHandler` and
  `0 errors found` are no longer counted as errors, and `WARN`, `FATAL` and `CRITICAL`
  are now recognised alongside `ERROR` and `WARNING`.
- Backup archives are created under `umask 077`, so they are not world-readable.
- Docker image moved from `ubuntu:22.04` to `alpine:3.20`, runs as a non-root user,
  and installs only the CLI: **107 MB → 20.5 MB** (measured with `docker images`).
  Bind-mounted runs should pass `--user "$(id -u):$(id -g)"`.

### Fixed

- The empty-directory message now names the pattern that was searched.

## [1.4.0] - 2026-07-25

### Fixed

- Backup archives stored the directory path instead of the log files; extracting one
  produced a deep directory chain rather than the logs.
- Every run left an uncompressed copy of the logs next to the archive, so each run
  stored the logs twice.
- `-t` accepted non-numeric input and leaked a raw bash error.
- Errors were printed to stdout instead of stderr.

### Added

- `--version` / `-V`.
- `tests/test_logsentry.sh`, a dependency-free test suite with real assertions,
  replacing `run_tests.sh` (which referenced fixtures that did not exist and could
  not fail).
- GitHub Actions CI: ShellCheck, the test suite on Ubuntu and macOS, and a Docker
  build check.
- `PREFIX` support in `install.sh` / `uninstall.sh` for installs without `sudo`.

### Changed

- `set -euo pipefail` throughout; file collection uses a glob instead of parsing `ls`.
- `scripts/generate_demo_logs.sh` works with GNU `date` as well as BSD `date`.
- Docker build context reduced from ~49.5 MB to ~60 KB via `.dockerignore`.

## [1.3.0] - 2026-05-15

- Dockerised runtime with bind-mounted reports and backups.
- Configurable runtime output directories.

[1.5.0]: https://github.com/dhananjay2403/logsentry-unix-cli/releases/tag/v1.5.0
[1.4.0]: https://github.com/dhananjay2403/logsentry-unix-cli/releases/tag/v1.4.0
[1.3.0]: https://github.com/dhananjay2403/logsentry-unix-cli/releases/tag/v1.3.0
