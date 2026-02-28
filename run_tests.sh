#!/bin/bash

SCRIPT="./logsentry"

echo ""
echo "Running LogSentry test suite..."
echo "--------------------------------"

run_test () {
  echo ""
  echo "# $1"
  "$SCRIPT" "$2" | grep -E "Log files found|Errors:|Warnings:|No log files found|Process completed"
}

run_test "Clean logs test" test_logs/clean
run_test "Error logs test" test_logs/errors
run_test "Real-world logs test" test_logs/real_world
run_test "Malformed logs test" test_logs/malformed
run_test "Empty directory test" test_logs/empty

echo ""
echo "All tests completed!"