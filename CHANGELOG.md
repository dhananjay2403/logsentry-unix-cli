# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-07-26

Analysis engine rewrite, a set of additive flags, real tests and CI. Existing
invocations (`logsentry`, `logsentry <dir>`, `-d`, `-t N`, `--top-errors=N`, `-h`,
and the `LOG_DIR` / `REPORT_DIR` / `BACKUP_ROOT` variables) behave exactly as
before, including the automatic backup on every run.

### Added

- `--json` — machine-readable summary with per-file results, for pipelines and `jq`.
- `--fail-on-error N` — exit status `2` once errors reach N, so the tool can gate CI.
- `-r`, `--recursive` and `--pattern GLOB` — analyse nested directories and rotated
  files such as `app.log.1`.
- `--quiet` — totals only.
- `--no-color`, plus support for the `NO_COLOR` environment convention.
- `--keep N` — keep only the N newest backup archives.
- `--version` / `-V`.
- Backups now report raw size, archive size, and the compression ratio.
- Reports include a per-file table and the total number of lines analysed.
- `tests/test_logsentry.sh`, a dependency-free test suite with real assertions,
  replacing `run_tests.sh` (which referenced fixtures that did not exist and could
  not fail).
- GitHub Actions CI: ShellCheck, the test suite on Ubuntu and macOS, and a Docker
  build whose container output is compared against the host run.
- `PREFIX` support in `install.sh` / `uninstall.sh` for installs without `sudo`.
- `scripts/benchmark.sh` — reproducible benchmark harness (median of repeated runs,
  validated timings) that writes its results into `docs/BENCHMARKS.md` and the README.
  No published figure is typed in by hand.
- `scripts/generate_logs.sh` — deterministic corpus generator for the benchmarks; the
  same command produces a byte-identical corpus on any machine.
- `docs/BENCHMARKS.md` — what each metric measures, how, how to reproduce it, and its caveats.
- `docs/demo.md` — the exact asciinema/agg workflow for recording the demo GIF.
- `packaging/logsentry.rb` and `packaging/README.md` — Homebrew formula and tap instructions.

### Changed

- Analysis now makes a **single pass per file** with a POSIX `awk` program instead of
  two to four `grep` / `sort` / `uniq` / `wc` passes.
- The awk engine rejects non-matching lines with a cheap case-class test before doing any
  case folding, since `tolower()` on every line was the hot path. Output is unchanged;
  reproduce the speedup with `BASELINE_REF=bcd27f5 ./scripts/benchmark.sh`.
- Log levels are matched as **whole words**. `error_rate=0`, `ErrorHandler` and
  `0 errors found` are no longer counted as errors, and `WARN`, `FATAL` and `CRITICAL`
  are now recognised alongside `ERROR` and `WARNING`.
- Human-readable output redesigned: compact header, aligned per-file table, labelled
  summary block and an aligned report/backup/archive footer. Error counts are red and
  warning counts yellow throughout; headings are bold. `--quiet` output is unchanged.
- The archive line states the direction of the size change, so small inputs read
  `374 B -> 578 B (54% larger)` instead of a negative percentage.
- Backup archives are created under `umask 077`, so they are not world-readable.
- Docker image moved from `ubuntu:22.04` to `alpine:3.20`, runs as a non-root user,
  and installs only the CLI. Sizes are measured by `scripts/benchmark.sh`; see
  [docs/BENCHMARKS.md](docs/BENCHMARKS.md). Bind-mounted runs should pass
  `--user "$(id -u):$(id -g)"`.
- `set -euo pipefail` throughout; file collection uses a glob instead of parsing `ls`.
- `scripts/generate_demo_logs.sh` works with GNU `date` as well as BSD `date`.
- Docker build context reduced to just the CLI by excluding demo media, PDFs and
  fixtures in `.dockerignore`.

### Fixed

- Backup archives stored the directory path instead of the log files; extracting one
  produced a deep directory chain rather than the logs.
- Every run left an uncompressed copy of the logs next to the archive, so each run
  stored the logs twice.
- `-t` accepted non-numeric input and leaked a raw bash error.
- Errors were printed to stdout instead of stderr.
- The empty-directory message now names the pattern that was searched.

## [1.3.0] - 2026-05-15

- Dockerised runtime with bind-mounted reports and backups.
- Configurable runtime output directories.

[1.4.0]: https://github.com/dhananjay2403/logsentry-unix-cli/releases/tag/v1.4.0
[1.3.0]: https://github.com/dhananjay2403/logsentry-unix-cli/releases/tag/v1.3.0
