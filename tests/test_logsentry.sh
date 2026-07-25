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

# Reads a value out of the "Total Summary" block, e.g. summary Errors -> 5
summary() { # label
  printf '%s\n' "$OUT" | grep "^$1: " | tail -1 | awk '{print $2}'
}

printf '\nRunning logsentry tests (bash %s)\n' "${BASH_VERSION}"
printf -- '----------------------------------------\n'

# --- counting -----------------------------------------------------------------

run "$FIXTURES/clean"
assert_eq "clean logs exit 0" "0" "$STATUS"
assert_eq "clean logs report 0 errors" "0" "$(summary Errors)"
assert_eq "clean logs report 0 warnings" "0" "$(summary Warnings)"
assert_contains "clean logs count 1 file" "$OUT" "Log files found: 1"

run "$FIXTURES/errors"
assert_eq "error fixtures total 5 errors across 2 files" "5" "$(summary Errors)"
assert_eq "error fixtures total 0 warnings" "0" "$(summary Warnings)"
assert_contains "per-file line shows api.log counts" "$OUT" "api.log → Errors: 3 Warnings: 0"

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
assert_contains "empty directory explains itself" "$OUT" "no log files found"

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

# --- results ------------------------------------------------------------------

printf -- '----------------------------------------\n'
printf '%s passed, %s failed\n\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
