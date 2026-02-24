#!/bin/bash

# LogSentry Unix CLI Tool
# This script analyzes log files in the logs directory

echo "Starting Log Analyzer..."

# Print current working directory
echo "Current directory: $(pwd)"

# Count number of log files
log_count=$(ls logs/*.log 2>/dev/null | wc -l)

echo "Number of log files found: $log_count"