#!/bin/bash

# LogSentry Unix CLI Tool
# This script analyzes log files in the logs directory

echo "Starting Log Analyzer..."
echo "--------------------------------"

# Count no. of log files
log_count=$(ls logs/*.log 2>/dev/null | wc -l)
echo "Log files found: $log_count"

# Count ERROR lines
error_count=$(grep -i "ERROR" logs/*.log 2>/dev/null | wc -l)

# Count WARNING lines
warning_count=$(grep -i "WARNING" logs/*.log 2>/dev/null | wc -l)

echo ""
echo "Analysis Summary:"
echo "Errors: $error_count"
echo "Warnings: $warning_count"