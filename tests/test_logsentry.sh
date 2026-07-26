#!/usr/bin/env bash
#
# Test suite for logsentry.
#
# Deliberately dependency-free: plain bash assertions instead of a test
# framework, so it runs identically on stock macOS (bash 3.2) and in CI.
# Every assertion checks a real value and the script exits non-zero if any
# assertion fails.
#
# Usage: ./tests/test_logsentry.sh

set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/logsentry"
FIXTURES="$ROOT/tests/fixtures"

WORK=$(mktemp -d)
RUN_DIR="$WORK/run"
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

pass() {
  printf 'ok    %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'FAIL  %s\n        %s\n' "$1" "$2"
  failed=$((failed + 1))
}

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected [$2], got [$3]"
  fi
}

assert_contains() { # name haystack needle
  case "$2" in
    *"$3"*) pass "$1" ;;
    *) fail "$1" "output does not contain [$3]" ;;
  esac
}

assert_not_contains() { # name haystack needle
  case "$2" in
    *"$3"*) fail "$1" "output unexpectedly contains [$3]" ;;
    *) pass "$1" ;;
  esac
}

# Runs logsentry with its report/backup output redirected into a throwaway
# directory, so tests never touch the repository. Sets OUT and STATUS.
OUT=""
STATUS=0
run() {
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"
  OUT=$(REPORT_DIR="$RUN_DIR/reports" BACKUP_ROOT="$RUN_DIR/backups" "$SCRIPT" "$@" 2>&1)
  STATUS=$?
}

# Same, but the log directory comes from the LOG_DIR environment variable
# instead of an argument.
run_with_log_dir() { # log_dir
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"
  OUT=$(LOG_DIR="$1" REPORT_DIR="$RUN_DIR/reports" BACKUP_ROOT="$RUN_DIR/backups" "$SCRIPT" 2>&1)
  STATUS=$?
}

# Reads a count from the summary block. Works for the aligned full-run format
# ("Errors         : 19") and the compact --quiet one ("Errors: 19").
summary() { # label
  printf '%s\n' "$OUT" | grep "^$1" | tail -1 | awk '{print $NF}'
}

# Column padding makes exact-match assertions brittle, so table rows are
# compared with runs of spaces collapsed.
squeeze() {
  printf '%s\n' "$1" | tr -s ' '
}

printf '\nRunning logsentry tests (bash %s)\n' "${BASH_VERSION}"
printf -- '----------------------------------------\n'

# --- counting -----------------------------------------------------------------

run "$FIXTURES/clean"
assert_eq "clean logs exit 0" "0" "$STATUS"
assert_eq "clean logs report 0 errors" "0" "$(summary Errors)"
assert_eq "clean logs report 0 warnings" "0" "$(summary Warnings)"
assert_contains "clean logs count 1 file" "$OUT" "Files analysed : 1"

run "$FIXTURES/errors"
assert_eq "error fixtures total 5 errors across 2 files" "5" "$(summary Errors)"
assert_eq "error fixtures total 0 warnings" "0" "$(summary Warnings)"
assert_contains "per-file row shows api.log counts" "$(squeeze "$OUT")" "api.log 3 0"

run "$FIXTURES/warnings"
assert_eq "warning fixtures total 3 warnings" "3" "$(summary Warnings)"
assert_eq "warning fixtures total 0 errors" "0" "$(summary Errors)"

run "$FIXTURES/mixed_case"
assert_eq "mixed case detects 3 errors" "3" "$(summary Errors)"
assert_eq "mixed case detects 2 warnings" "2" "$(summary Warnings)"

run "$FIXTURES/malformed"
assert_eq "malformed logs still find 1 error" "1" "$(summary Errors)"
assert_eq "malformed logs still find 1 warning" "1" "$(summary Warnings)"

mkdir -p "$WORK/spaced"
printf '2026-03-01 10:00:00 ERROR boom\n' > "$WORK/spaced/my app.log"
run "$WORK/spaced"
assert_eq "filename with a space is analysed" "1" "$(summary Errors)"

run_with_log_dir "$FIXTURES/warnings"
assert_eq "LOG_DIR environment variable is honoured" "3" "$(summary Warnings)"

# --- failure handling ---------------------------------------------------------

run "$FIXTURES/does_not_exist"
assert_eq "missing directory exits 1" "1" "$STATUS"
assert_contains "missing directory explains itself" "$OUT" "directory not found"

run "$FIXTURES/empty"
assert_eq "directory without log files exits 1" "1" "$STATUS"
assert_contains "empty directory explains itself" "$OUT" "no files matching"

run -t abc "$FIXTURES/errors"
assert_eq "non-numeric -t exits 1" "1" "$STATUS"
assert_contains "non-numeric -t explains itself" "$OUT" "expects a positive number"
assert_not_contains "non-numeric -t leaks no bash error" "$OUT" "integer expression expected"

run --bogus "$FIXTURES/errors"
assert_eq "unknown option exits 1" "1" "$STATUS"
assert_contains "unknown option explains itself" "$OUT" "unknown option"

# --- flags --------------------------------------------------------------------

run -d "$FIXTURES/errors"
assert_contains "--details lists ERROR lines" "$OUT" "--- ERROR lines (file: api.log)"

run -t 2 "$FIXTURES/errors"
assert_contains "-t ranks repeated errors first" "$OUT" "2 2026-03-01 10:00:05 ERROR Failed to connect to upstream"

run --top-errors=2 "$FIXTURES/errors"
assert_contains "--top-errors=N form works" "$OUT" "Top 2 ERROR lines"

run --help
assert_eq "--help exits 0" "0" "$STATUS"
assert_contains "--help shows usage" "$OUT" "Usage:"

run --version
assert_eq "--version exits 0" "0" "$STATUS"
assert_contains "--version prints the tool name" "$OUT" "logsentry "

# --- level matching -----------------------------------------------------------

run "$FIXTURES/tricky"
assert_eq "word-boundary matching counts only real error levels" "4" "$(summary Errors)"
assert_eq "word-boundary matching counts WARN and WARNING" "2" "$(summary Warnings)"
run -d "$FIXTURES/tricky"
matched_lines=$(printf '%s\n' "$OUT" | sed -n 's/^    [0-9]*://p')
assert_not_contains "error_rate=0 is never reported as a matched line" "$matched_lines" "error_rate"
assert_contains "FATAL is reported as an error line" "$matched_lines" "FATAL Out of memory"

# --- recursion and patterns ---------------------------------------------------

run "$FIXTURES/nested"
assert_contains "non-recursive stays at the top level" "$OUT" "Files analysed : 1"

run -r "$FIXTURES/nested"
assert_contains "--recursive descends into sub-directories" "$OUT" "Files analysed : 2"
assert_eq "--recursive aggregates nested errors" "3" "$(summary Errors)"
assert_contains "--recursive shows the path relative to the log directory" "$OUT" "svc/deep.log"

run --pattern '*.log*' "$FIXTURES/nested"
assert_contains "--pattern picks up rotated files" "$OUT" "Files analysed : 2"
assert_eq "--pattern aggregates matching files" "2" "$(summary Errors)"

# --- exit codes ---------------------------------------------------------------

run --fail-on-error 5 "$FIXTURES/errors"
assert_eq "--fail-on-error exits 2 at the threshold" "2" "$STATUS"

run --fail-on-error 6 "$FIXTURES/errors"
assert_eq "--fail-on-error exits 0 below the threshold" "0" "$STATUS"

run --fail-on-error abc "$FIXTURES/errors"
assert_eq "non-numeric --fail-on-error exits 1" "1" "$STATUS"

# --- output modes -------------------------------------------------------------

run -q "$FIXTURES/errors"
assert_eq "--quiet still reports the totals" "5" "$(summary Errors)"
assert_not_contains "--quiet drops the per-file section" "$OUT" "Per-file summary"
assert_not_contains "--quiet drops the banner" "$OUT" "LogSentry v"

run --json "$FIXTURES/errors"
assert_eq "--json exits 0" "0" "$STATUS"
assert_contains "--json reports totals" "$OUT" '"errors": 5'
assert_contains "--json lists each file" "$OUT" '"file": "api.log"'
assert_not_contains "--json prints nothing but JSON" "$OUT" "LogSentry v"
if command -v python3 > /dev/null 2>&1; then
  if printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null; then
    pass "--json output parses as JSON"
  else
    fail "--json output parses as JSON" "python3 could not parse the document"
  fi
fi

run --no-color "$FIXTURES/errors"
assert_not_contains "--no-color emits no escape sequences" "$OUT" "$(printf '\033')"

# --- artifacts ----------------------------------------------------------------

run "$FIXTURES/errors"
report="$RUN_DIR/reports/report.txt"
if [ -f "$report" ]; then
  assert_eq "report starts with its title (no blank first line)" \
    "Log Analysis Report" "$(head -1 "$report")"
  assert_eq "report records the error total" "5" "$(grep '^Errors: ' "$report" | awk '{print $2}')"
else
  fail "report is generated" "no file at $report"
  fail "report records the error total" "no file at $report"
fi

archives=("$RUN_DIR/backups"/*.tar.gz)
archive="${archives[0]}"
if [ -f "$archive" ]; then
  members=$(tar -tzf "$archive" | sort | paste -sd, -)
  assert_eq "archive holds plain file names, not a directory path" "api.log,worker.log" "$members"
else
  fail "archive is created" "no .tar.gz in $RUN_DIR/backups"
fi

entries=$(find "$RUN_DIR/backups" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
assert_eq "backup leaves only the archive behind (no staging copy)" "1" "$entries"
assert_eq "every run still creates a backup" "1" "$entries"

if [ -f "$report" ]; then
  assert_contains "report includes the per-file table header" "$(cat "$report")" "File"
  assert_contains "report includes a per-file row" "$(cat "$report")" "api.log"
  assert_contains "report records the line total" "$(cat "$report")" "Lines analyzed:"
else
  fail "report includes the per-file table" "no file at $report"
fi

run "$FIXTURES/errors"
assert_contains "backup reports the archive size change" "$OUT" "Archive : "
assert_not_contains "size change is never a negative percentage" "$OUT" "(-"

# --keep prunes older archives; three runs into one directory, keeping two.
keep_dir="$WORK/keep"
rm -rf "$keep_dir"
mkdir -p "$keep_dir"
for _ in 1 2 3; do
  REPORT_DIR="$keep_dir/reports" BACKUP_ROOT="$keep_dir/backups" \
    "$SCRIPT" --keep 2 "$FIXTURES/errors" > /dev/null 2>&1
  sleep 1 # archive names are per-second timestamps
done
kept=$(find "$keep_dir/backups" -name '*.tar.gz' | wc -l | tr -d ' ')
assert_eq "--keep 2 leaves exactly two archives" "2" "$kept"

# --- packaging ----------------------------------------------------------------

script_version=$("$SCRIPT" --version | awk '{print $2}')
docker_version=$(sed -n 's/.*image.version="\([^"]*\)".*/\1/p' "$ROOT/Dockerfile")
assert_eq "Dockerfile version label matches the script" "$script_version" "$docker_version"

# --- results ------------------------------------------------------------------

printf -- '----------------------------------------\n'
printf '%s passed, %s failed\n\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
