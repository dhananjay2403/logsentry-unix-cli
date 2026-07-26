#!/usr/bin/env bash
#
# Benchmark harness for logsentry. Every number published in the README and
# docs/BENCHMARKS.md comes from here; see that file for method and caveats.
#
# Usage:
#   scripts/benchmark.sh [--quick | --full] [--markdown]

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/logsentry"
GENERATOR="$ROOT/scripts/generate_logs.sh"

# Previous version to compare against.
BASELINE_REF="${BASELINE_REF:-v1.4.0}"

SIZES="100000 1000000"
PRESET=""
REPS=5
BASELINE_SIZE=1000000
BASELINE_REPS=3
MARKDOWN=0

usage() {
  cat <<HELP
Usage:
  benchmark.sh [options]

Options:
  --quick        100k lines only, 3 repetitions (fast sanity check)
  --full         Adds a 5M-line tier (several minutes)
  --markdown     Also write the results into docs/BENCHMARKS.md and README.md
  -h, --help     Show this help

Environment:
  BASELINE_REF   Git ref holding the previous implementation (default: v1.4.0)
HELP
}

die() {
  printf 'benchmark: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --quick)
      PRESET=" --quick"
      SIZES="100000"
      REPS=3
      BASELINE_SIZE=100000
      shift
      ;;
    --full)
      PRESET=" --full"
      SIZES="100000 1000000 5000000"
      shift
      ;;
    --markdown)
      MARKDOWN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -x "$SCRIPT" ] || die "logsentry not found at $SCRIPT"
[ -x "$GENERATOR" ] || die "generator not found at $GENERATOR"
command -v /usr/bin/time > /dev/null 2>&1 || die "/usr/bin/time is required for timing"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Keep everything the tool writes inside the temp directory.
export REPORT_DIR="$WORK/reports"
export BACKUP_ROOT="$WORK/backups"

RESULTS="$WORK/results.md"
SCALING="$WORK/scaling.md"
: > "$RESULTS"
: > "$SCALING"

# Filled in as each section runs; assembled into the README block at the end.
SUM_THROUGHPUT=""
SUM_SCALE=""
SUM_MEMORY=""
SUM_DOCKER="not measured"
SUM_DOCKER_DELTA=""
SUM_COMPRESSION=""

# --- measurement helpers ---

# Median of the numbers on stdin.
median() {
  sort -n | awk '{ v[NR] = $1 }
    END {
      if (NR == 0) exit 1
      printf "%.2f", (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
    }'
}

# Wall-clock seconds for one run. Aborts rather than reporting a bogus 0.00.
time_once() {
  local out real
  if ! out=$( { /usr/bin/time -p "$@" > /dev/null; } 2>&1 ); then
    printf 'benchmark: command failed: %s\n' "$*" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  real=$(printf '%s\n' "$out" | awk '/^real/ { print $2 }')
  case "$real" in
    '' | *[!0-9.]*) die "could not parse a timing from: $*" ;;
  esac
  printf '%s\n' "$real"
}

# Warm-up run (discarded), then the median of $1 timed runs.
time_median() {
  local reps="$1"
  shift
  time_once "$@" > /dev/null
  local _
  for _ in $(seq 1 "$reps"); do
    time_once "$@"
  done | median
}

# Peak resident memory in MB. macOS uses -l (bytes), GNU uses -v (kbytes).
peak_rss_mb() {
  local out
  if /usr/bin/time -l true > /dev/null 2>&1; then
    out=$( { /usr/bin/time -l "$@" > /dev/null; } 2>&1 )
    printf '%s\n' "$out" |
      awk '/maximum resident set size/ { printf "%.1f", $1 / 1048576; exit }'
  else
    out=$( { /usr/bin/time -v "$@" > /dev/null; } 2>&1 )
    printf '%s\n' "$out" |
      awk -F': *' '/Maximum resident set size/ { printf "%.1f", $2 / 1024; exit }'
  fi
}

human_size() { # bytes -> MB with one decimal
  awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'
}

# Size as `docker images` prints it. Not `docker image inspect .Size`, which
# reports the compressed content size under the containerd image store.
image_size() {
  docker images --format '{{.Size}}' "$1" | head -1
}

# "20.5MB" -> bytes, so the percentage comes from the same source.
size_to_bytes() {
  awk -v s="$1" 'BEGIN {
    n = s + 0
    if (s ~ /GB/)      m = 1000000000
    else if (s ~ /MB/) m = 1000000
    else if (s ~ /kB/) m = 1000
    else               m = 1
    printf "%d", n * m
  }'
}

# 5000000 -> 5M, 100000 -> 100k. Used to name the tier in the summary row.
size_label() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000)   printf "%gM", n / 1000000
    else if (n >= 1000) printf "%gk", n / 1000
    else                printf "%d", n
  }'
}

# 1234567 -> 1,234,567. printf "%'d" silently does nothing on macOS.
commify() {
  awk -v n="$1" 'BEGIN {
    s = sprintf("%d", n)
    out = ""
    while (length(s) > 3) {
      out = "," substr(s, length(s) - 2) out
      s = substr(s, 1, length(s) - 3)
    }
    printf "%s%s", s, out
  }'
}

emit() { printf '%s\n' "$1" | tee -a "$RESULTS"; }

# --- environment ---

cpu_model() {
  if [ -r /proc/cpuinfo ]; then
    awk -F': ' '/model name/ { print $2; exit }' /proc/cpuinfo
  else
    sysctl -n machdep.cpu.brand_string 2> /dev/null || printf 'unknown'
  fi
}

awk_version() {
  local v
  v=$(awk --version 2>&1 | head -1)
  case "$v" in
    *"not an option"* | *illegal* | *usage* | '') v=$(awk -W version 2>&1 | head -1) ;;
  esac
  printf '%s' "$v"
}

emit "_Generated by \`scripts/benchmark.sh\` on $(date -u '+%Y-%m-%d %H:%M UTC')._"
emit ""
emit "| Environment | |"
emit "|---|---|"
emit "| OS | $(uname -s) $(uname -r) ($(uname -m)) |"
emit "| CPU | $(cpu_model) |"
emit "| Shell | $(bash --version | head -1) |"
emit "| awk | $(awk_version) |"
emit "| logsentry | $("$SCRIPT" --version) |"
emit ""

# --- throughput, scaling and memory ---

emit "### Throughput, scaling and memory"
emit ""
emit "Median of $REPS timed runs per size (one warm-up run discarded), end to end:"
emit "analysis, report and backup archive."
emit ""
emit "| Lines | Corpus size | Median wall time | Throughput | Peak memory |"
emit "|---|---|---|---|---|"

largest_corpus=""
for size in $SIZES; do
  corpus="$WORK/corpus-$size"
  "$GENERATOR" --lines "$size" --files 4 --out "$corpus" > /dev/null
  largest_corpus="$corpus"

  bytes=$(cat "$corpus"/*.log | wc -c | tr -d ' ')
  secs=$(time_median "$REPS" "$SCRIPT" "$corpus")
  rss=$(peak_rss_mb "$SCRIPT" "$corpus")
  rate=$(awk -v l="$size" -v s="$secs" 'BEGIN { printf "%d", (s > 0 ? l / s : 0) }')

  emit "| $(commify "$size") | $(human_size "$bytes") MB | ${secs}s | $(commify "$rate") lines/s | ${rss} MB |"

  printf '| %s | %s MB | %ss | %s lines/s | %s MB |\n' \
    "$(commify "$size")" "$(human_size "$bytes")" "$secs" "$(commify "$rate")" "$rss" >> "$SCALING"

  # The summary quotes the largest tier, so later sizes overwrite earlier ones.
  SUM_THROUGHPUT="$(commify "$rate") lines/s"
  SUM_SCALE="$(size_label "$size")-line benchmark"
  SUM_MEMORY="${rss} MB"
done
emit ""

# --- comparison against the previous implementation ---

emit "### Current engine vs the previous implementation"
emit ""

baseline="$WORK/logsentry-baseline"
if git -C "$ROOT" rev-parse --verify --quiet "$BASELINE_REF" > /dev/null 2>&1 &&
  git -C "$ROOT" show "$BASELINE_REF:logsentry" > "$baseline" 2> /dev/null; then
  chmod +x "$baseline"
  corpus="$WORK/corpus-$BASELINE_SIZE"
  [ -d "$corpus" ] || "$GENERATOR" --lines "$BASELINE_SIZE" --files 4 --out "$corpus" > /dev/null

  emit "Both versions on the same corpus ($BASELINE_SIZE lines), median of $BASELINE_REPS runs."
  emit "\`$BASELINE_REF\` used multiple \`grep\` passes per file; the current version uses one awk pass."
  emit ""
  emit "| Mode | $BASELINE_REF | current | difference |"
  emit "|---|---|---|---|"

  for mode in "default" "-d" "-t 3"; do
    case "$mode" in
      default) set -- ;;
      -d) set -- -d ;;
      *) set -- -t 3 ;;
    esac
    old=$(time_median "$BASELINE_REPS" "$baseline" "$@" "$corpus")
    new=$(time_median "$BASELINE_REPS" "$SCRIPT" "$@" "$corpus")
    delta=$(awk -v o="$old" -v n="$new" 'BEGIN {
      if (o <= 0) { printf "n/a"; exit }
      d = (o - n) / o * 100
      if (d >= 1)       printf "%.0f%% faster", d
      else if (d <= -1) printf "%.0f%% slower", -d
      else              printf "no measurable difference"
    }')
    emit "| \`$mode\` | ${old}s | ${new}s | $delta |"
  done
  emit ""
else
  emit "_Skipped: baseline ref \`$BASELINE_REF\` not found._"
  emit "Create it with \`git tag $BASELINE_REF <commit>\`, or run with \`BASELINE_REF=<ref>\`."
  emit ""
fi

# --- compression ---

emit "### Backup compression"
emit ""
compress_line=$("$SCRIPT" "$largest_corpus" | awk '/^Compressed/ { print; exit }')
raw=$(printf '%s' "$compress_line" | awk '{ print $2 }')
gz=$(printf '%s' "$compress_line" | awk '{ print $5 }')
pct=$(printf '%s' "$compress_line" | awk '{ print $7 }' | tr -d '(')
emit "| Raw logs | Archive | Saved |"
emit "|---|---|---|"
emit "| $(human_size "$raw") MB | $(human_size "$gz") MB | $pct |"
emit ""
SUM_COMPRESSION="$pct ($(human_size "$raw") MB of logs to $(human_size "$gz") MB)"

# --- docker image size ---

emit "### Docker image size"
emit ""
if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
  docker build -q -t logsentry:bench "$ROOT" > /dev/null
  current_size=$(image_size logsentry:bench)

  emit "Sizes as reported by \`docker images\` (uncompressed, on disk)."
  emit ""
  emit "| Image | Size |"
  emit "|---|---|"
  emit "| current (\`Dockerfile\`) | $current_size |"
  SUM_DOCKER="$current_size"

  ctx="$WORK/baseline-image"
  if [ -f "$baseline" ] && mkdir -p "$ctx" &&
    git -C "$ROOT" show "$BASELINE_REF:Dockerfile" > "$ctx/Dockerfile" 2> /dev/null; then
    cp "$baseline" "$ctx/logsentry"
    docker build -q -t logsentry:bench-baseline "$ctx" > /dev/null
    old_size=$(image_size logsentry:bench-baseline)
    emit "| $BASELINE_REF (\`ubuntu:22.04\`) | $old_size |"
    emit ""
    reduction=$(awk -v o="$(size_to_bytes "$old_size")" -v n="$(size_to_bytes "$current_size")" \
      'BEGIN { printf "%.0f%%", (o - n) / o * 100 }')
    emit "Current image is $reduction smaller than \`$BASELINE_REF\`."
    SUM_DOCKER_DELTA="$reduction smaller than the previous \`ubuntu:22.04\` image"
  fi
  emit ""
else
  emit "_Skipped: the Docker daemon is not reachable._"
  emit ""
fi

# --- project health rows for the summary table ---

test_suite_result() {
  local out
  out=$("$ROOT/tests/test_logsentry.sh" 2>&1) || true
  printf '%s\n' "$out" | awk '/passed,/ { printf "%s / %s passing", $1, $1 + $3; found = 1 }
    END { if (!found) printf "not run" }'
}

shellcheck_result() {
  command -v shellcheck > /dev/null 2>&1 || {
    printf 'not run (shellcheck not installed)'
    return
  }
  local n
  n=$(shellcheck -S style -f gcc "$ROOT"/logsentry "$ROOT"/install.sh "$ROOT"/uninstall.sh \
    "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    printf "zero warnings (\`-S style\`)"
  else
    printf "%s findings (\`-S style\`)" "$n"
  fi
}

# --- write results into the docs ---

# Replace the lines between two markers, leaving the rest byte-for-byte intact.
splice() { # file start_marker end_marker content_file
  local file="$1" start="$2" end="$3" content="$4"
  if ! grep -q -- "$start" "$file" 2> /dev/null; then
    printf 'benchmark: %s has no %s marker, skipping\n' "$file" "$start" >&2
    return 0
  fi
  awk -v start="$start" -v end="$end" -v content="$content" '
    index($0, start) { print; while ((getline line < content) > 0) print line; skip = 1; next }
    index($0, end)   { skip = 0 }
    !skip            { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

if [ "$MARKDOWN" -eq 1 ]; then
  splice "$ROOT/docs/BENCHMARKS.md" "<!-- BENCHMARK RESULTS START -->" \
    "<!-- BENCHMARK RESULTS END -->" "$RESULTS"

  {
    printf '\n'
    printf "Measured with \`./scripts/benchmark.sh%s\` on %s (%s %s, bash %s).\n" \
      "$PRESET" "$(cpu_model)" "$(uname -s)" "$(uname -m)" "${BASH_VERSION%%(*}"
    printf '\n'
    printf '### Performance summary\n\n'
    printf '| Metric | Measured |\n'
    printf '|---|---|\n'
    printf '| Throughput (%s) | %s |\n' "$SUM_SCALE" "$SUM_THROUGHPUT"
    printf '| Peak memory | %s |\n' "$SUM_MEMORY"
    printf '| Docker image | %s |\n' "$SUM_DOCKER"
    [ -n "$SUM_DOCKER_DELTA" ] && printf '| Docker image reduction | %s |\n' "$SUM_DOCKER_DELTA"
    printf '| Compression ratio | %s |\n' "$SUM_COMPRESSION"
    printf '| Automated tests | %s |\n' "$(test_suite_result)"
    printf '| ShellCheck | %s |\n' "$(shellcheck_result)"
    printf '\n### Scaling\n\n'
    printf '| Lines | Corpus size | Median time | Throughput | Peak memory |\n'
    printf '|---|---|---|---|---|\n'
    cat "$SCALING"
    printf '\n'
    printf '_Median of %s runs per size after a discarded warm-up, end to end (analysis, report,\n' "$REPS"
    printf 'archive). Memory stays flat as the corpus grows because the engine streams with awk.\n'
    printf 'Method and caveats: [docs/BENCHMARKS.md](docs/BENCHMARKS.md)._\n'
  } > "$WORK/readme-block.md"

  splice "$ROOT/README.md" "<!-- BENCHMARK SUMMARY START -->" \
    "<!-- BENCHMARK SUMMARY END -->" "$WORK/readme-block.md"

  printf '\nWrote results into docs/BENCHMARKS.md and README.md\n'
fi
