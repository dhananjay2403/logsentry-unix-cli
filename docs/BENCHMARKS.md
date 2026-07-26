# Benchmarks

Every number in this file is produced by [`scripts/benchmark.sh`](../scripts/benchmark.sh).
Nothing is typed in by hand. Re-running the harness overwrites the results block below with
measurements from your machine, so if a number here looks wrong, run it and see.

## Running the benchmarks

```bash
./scripts/benchmark.sh --quick      # 100k lines, 3 runs (~1 minute)
./scripts/benchmark.sh              # 100k + 1M lines, 5 runs
./scripts/benchmark.sh --full       # adds a 5M-line tier (several minutes)
./scripts/benchmark.sh --markdown   # also rewrite the results in this file and the README
```

The comparison against the previous implementation needs a git ref to compare with:

```bash
git tag v1.4.0 8e38714              # one-time, if the tag does not exist yet
BASELINE_REF=v1.4.0 ./scripts/benchmark.sh
```

If the ref cannot be resolved, that one metric is skipped with a message and everything else
still runs.

## Method

**Deterministic corpus.** [`scripts/generate_logs.sh`](../scripts/generate_logs.sh) picks each
line's content from arithmetic on the line number rather than `rand()`, so the same command
produces a byte-identical corpus on every machine and every awk implementation. Two people on
different laptops are therefore measuring the same work. The mix is 2 ERROR lines in 17 (~11.8%)
and 1 WARNING in 17 (~5.9%), with error messages drawn from a small repeating set so that
ranking (`-t N`) has something real to count.

**Warm-up and median.** Each measurement runs the command once and throws that result away, so
the corpus is in the page cache for the runs that count. It then takes several timed runs and
reports the **median**, not the mean — one scheduler hiccup cannot drag the number around.

**Timing.** Wall time comes from `/usr/bin/time -p`. The `-p` flag is POSIX and prints the same
`real <seconds>` format on macOS and Linux, which avoids parsing two different output layouts.

**Validated readings.** Every measurement checks the command's exit status and confirms the
parsed value is numeric. A command that fails aborts the whole run. This is deliberate: while
building the harness, a silently-failing command reported `0.00s`, which would have produced a
spectacular and completely fictional throughput number.

**End to end.** Timings cover a full `logsentry` run — analysis, report generation, and creating
the compressed backup archive — because that is what a user actually waits for, not an isolated
inner loop.

## What each metric means

### Throughput and scaling

*What:* lines processed per second, and whether that rate holds as the corpus grows.
*How:* median wall time for a complete run over a generated corpus; throughput is
lines ÷ median seconds.
*Reproduce:* `./scripts/benchmark.sh` (add `--full` for the 5M tier).
*Caveats:* throughput depends heavily on line length and the ERROR/WARNING ratio, since matching
lines do more work than lines that are rejected by the pre-filter. The generated corpus is one
specific shape; your logs will differ.

### Peak memory

*What:* the high-water mark of resident memory for a run.
*How:* `/usr/bin/time -l` on macOS (reports bytes) or `/usr/bin/time -v` on Linux (reports
kbytes); the harness detects which is available.
*Reproduce:* same command as above — memory is measured once per size, since it is stable.
*Why it matters:* the analysis engine streams with `awk`, holding one line at a time rather than
reading a file into memory, so peak memory stays roughly flat as the corpus grows. Compare the
memory column across the size rows to see this.
*Caveats:* `/usr/bin/time` reports the peak for the process and the children it waits for, which
is what we want here, but it is a coarse figure and includes the shell itself.

### Current engine vs the previous implementation

*What:* the current single-pass `awk` engine against the multi-pass `grep` implementation it
replaced, on identical input, per CLI mode.
*How:* both scripts are run over the same corpus; the older one is extracted straight from git
(`git show "$BASELINE_REF:logsentry"`), so no copy of the old code is carried in the repository.
*Reproduce:* `BASELINE_REF=v1.4.0 ./scripts/benchmark.sh`.

*Read this one honestly.* The rewrite was **not** primarily a performance change, and depending
on the platform it is not a speedup at all. GNU `grep` is heavily optimised, and on GNU userland
it can run several passes over a file faster than a single `awk` pass. The engine was changed for
what it makes possible in one pass — counts plus line totals, ranked errors, detail lines, and
JSON output — and for correct whole-word level matching. Where it does win consistently is the
flag-heavy modes (`-d`, `-t N`), because the old implementation needed extra passes and a
`sort | uniq -c | sort` pipeline for those.

*Caveats:* results differ substantially between BSD userland (macOS) and GNU userland (most
Linux distributions), in both directions. Run the harness on the platform you actually care
about rather than trusting a number measured elsewhere.

### Backup compression

*What:* how much smaller the `.tar.gz` archive is than the logs it came from.
*How:* parsed from `logsentry`'s own output line (`Compressed X bytes to Y bytes (Z% smaller)`),
so the documented figure is exactly what the tool reports to a user.
*Reproduce:* `./scripts/benchmark.sh`, or just run `logsentry` on any directory.
*Caveats:* the generated corpus is synthetic and highly repetitive, so its compression ratio is
an optimistic upper bound. Real logs with high-entropy fields (UUIDs, tokens, stack traces)
compress less.

### Docker image size

*What:* the size of the current image, and of the pre-Alpine image for comparison.
*How:* both are built locally and read from `docker images --format '{{.Size}}'`.
The baseline `Dockerfile` also comes from git rather than a committed copy.
*Reproduce:* `./scripts/benchmark.sh` with the Docker daemon running.
*Caveats:* this is the uncompressed on-disk size, which is what `docker images` prints and what
people usually quote; the compressed size pulled from a registry is smaller. Note that
`docker image inspect --format '{{.Size}}'` reports a *different* (compressed content) figure
when the containerd image store is enabled, which is why the harness reads `docker images`
instead. Skipped cleanly when Docker is unavailable.

## Results

<!-- BENCHMARK RESULTS START -->
_Generated by `scripts/benchmark.sh` on 2026-07-26 08:43 UTC._

| Environment | |
|---|---|
| OS | Darwin 25.5.0 (arm64) |
| CPU | Apple M2 |
| Shell | GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25) |
| awk | awk version 20200816 |
| logsentry | logsentry 1.5.0 |

### Throughput, scaling and memory

Median of 5 timed runs per size (one warm-up run discarded), end to end:
analysis, report and backup archive.

| Lines | Corpus size | Median wall time | Throughput | Peak memory |
|---|---|---|---|---|
| 100,000 | 5.4 MB | 0.29s | 344,827 lines/s | 3.6 MB |
| 1,000,000 | 55.1 MB | 2.49s | 401,606 lines/s | 3.6 MB |
| 5,000,000 | 278.9 MB | 11.22s | 445,632 lines/s | 3.7 MB |

### Current engine vs the previous implementation

Both versions on the same corpus (1000000 lines), median of 3 runs.
`8e38714` used multiple `grep` passes per file; the current version uses one awk pass.

| Mode | 8e38714 | current | difference |
|---|---|---|---|
| `default` | 3.04s | 2.83s | 7% faster |
| `-d` | 5.58s | 4.90s | 12% faster |
| `-t 3` | 5.17s | 3.57s | 31% faster |

### Backup compression

| Raw logs | Archive | Saved |
|---|---|---|
| 278.9 MB | 25.9 MB | 90% |

### Docker image size

Sizes as reported by `docker images` (uncompressed, on disk).

| Image | Size |
|---|---|
| current (`Dockerfile`) | 20.5MB |
| 8e38714 (`ubuntu:22.04`) | 107MB |

Current image is 81% smaller than `8e38714`.

<!-- BENCHMARK RESULTS END -->

## Caveats that apply to everything here

- Numbers come from one machine, stamped in the results block. Laptops thermally throttle;
  a busy machine measures slower. Compare rows within a single run, not across runs on
  different hardware.
- The benchmark writes reports and archives into a temporary directory, so it never pollutes the
  repository and never measures the cost of writing into a directory that already holds hundreds
  of old archives.
- These are wall-clock measurements on a warm page cache. First-run performance against cold
  storage will be slower and is dominated by I/O, not by the tool.
