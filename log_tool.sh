#!/bin/bash

# LogSentry Unix CLI Tool
# This script analyzes log files in the logs directory

echo "Starting Log Analyzer..."
echo "--------------------------------"

# Count number of log files
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

# Generate report
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

echo "" > report.txt
echo "Log Analysis Report" >> report.txt
echo "Generated at: $timestamp" >> report.txt
echo "--------------------------------" >> report.txt
echo "Log files analyzed: $log_count" >> report.txt
echo "Errors: $error_count" >> report.txt
echo "Warnings: $warning_count" >> report.txt

echo ""
echo "Report generated: report.txt"