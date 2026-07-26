#!/usr/bin/env bash
#
# Generates a log corpus for benchmarking.
#
# Content comes from arithmetic on the line number, never rand(), so the corpus
# is byte-identical on every machine and awk implementation - that is what makes
# numbers measured on different machines comparable.
#
# Mix: 2 lines in 17 ERROR, 1 in 17 WARNING, rest INFO. Error messages repeat
# from a small set so ranking (-t N) has something to count.
#
# Usage:
#   scripts/generate_logs.sh --out DIR [--lines N] [--files K]

set -euo pipefail

LINES=100000
FILES=1
OUT=""

usage() {
  cat <<HELP
Usage:
  generate_logs.sh --out DIR [--lines N] [--files K]

Options:
  --out DIR      Directory to write the corpus into (required)
  --lines N      Total number of log lines to generate (default: 100000)
  --files K      Spread the lines over K files (default: 1)
  -h, --help     Show this help
HELP
}

die() {
  printf 'generate_logs: %s\n' "$1" >&2
  exit 1
}

is_number() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2-}"
      [ -n "$OUT" ] || die "--out requires a directory"
      shift 2
      ;;
    --lines)
      is_number "${2-}" || die "--lines expects a number"
      LINES="$2"
      shift 2
      ;;
    --files)
      is_number "${2-}" || die "--files expects a number"
      FILES="$2"
      shift 2
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

[ -n "$OUT" ] || die "--out is required"
[ "$FILES" -gt 0 ] || die "--files must be at least 1"
[ "$LINES" -ge "$FILES" ] || die "--lines must be at least --files"

mkdir -p "$OUT"
rm -f "$OUT"/*.log

per_file=$((LINES / FILES))
remainder=$((LINES - per_file * FILES))

i=1
start=0
while [ "$i" -le "$FILES" ]; do
  count=$per_file
  # The first file absorbs the remainder so the totals come out exact.
  [ "$i" -eq 1 ] && count=$((count + remainder))

  awk -v n="$count" -v start="$start" -v svc="svc-$i" 'BEGIN {
    split("Connection timeout after 30s|Upstream returned 502 Bad Gateway|Failed to serialize response|Database deadlock detected", err, "|")
    split("High latency above 500ms|Queue depth above threshold|Slow query detected", wrn, "|")
    split("Request processed|Health check passed|Cache warmed|Job completed", inf, "|")

    for (k = 0; k < n; k++) {
      j = start + k
      ts = sprintf("2026-03-01 %02d:%02d:%02d", int(j / 3600) % 24, int(j / 60) % 60, j % 60)
      m = j % 17
      if (m == 0 || m == 5)
        printf "%s ERROR %s %s\n", ts, svc, err[(j % 4) + 1]
      else if (m == 3)
        printf "%s WARNING %s %s\n", ts, svc, wrn[(j % 3) + 1]
      else
        printf "%s INFO %s %s id=%d\n", ts, svc, inf[(j % 4) + 1], j
    }
  }' > "$OUT/svc-$i.log"

  start=$((start + count))
  i=$((i + 1))
done

printf 'Generated %s lines across %s file(s) in %s\n' "$LINES" "$FILES" "$OUT"
