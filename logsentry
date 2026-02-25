#!/bin/bash

# Accept directory argument (default: logs)
LOG_DIR=${1:-logs}

# Check if directory exists
if [ ! -d "$LOG_DIR" ]; then
  echo "Directory not found: $LOG_DIR"
  exit 1
fi

# Safety Check: Ensure logs exist
if ! ls "$LOG_DIR"/*.log 1> /dev/null 2>&1; then
  echo "No log files found in directory: $LOG_DIR"
  exit 1
fi


# CLI Header
echo ""
echo "================================"
echo "   LogSentry Unix CLI Tool"
echo "================================"
echo ""

echo "Starting Log Analyzer..."
echo "--------------------------------"


# Count no. of log files
log_count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l | xargs)
echo "Log files found: $log_count"


# Per-file analysis
echo ""
echo "Per-file analysis:"
echo "-------------------"

total_errors=0
total_warnings=0

for logfile in "$LOG_DIR"/*.log; do
  filename=$(basename "$logfile")

  file_errors=$(grep -i "ERROR" "$logfile" 2>/dev/null | wc -l | xargs)
  file_warnings=$(grep -i "WARNING" "$logfile" 2>/dev/null | wc -l | xargs)

  echo "$filename → Errors: $file_errors Warnings: $file_warnings"

  total_errors=$((total_errors + file_errors))
  total_warnings=$((total_warnings + file_warnings))
done


# Count ERROR lines
# error_count=$(grep -i "ERROR" "$LOG_DIR"/*.log 2>/dev/null | wc -l | xargs)         # previously
error_count=$total_errors


# Count WARNING lines
# warning_count=$(grep -i "WARNING" "$LOG_DIR"/*.log 2>/dev/null | wc -l | xargs)         # previously
warning_count=$total_warnings


echo ""
echo "Total Summary:"
echo "Errors: $error_count"
echo "Warnings: $warning_count"


# Generate report
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

echo "" > report.txt
echo "Log Analysis Report" >> report.txt
echo "Generated at: $timestamp" >> report.txt
echo "Directory analyzed: $LOG_DIR" >> report.txt
echo "--------------------------------" >> report.txt
echo "Log files analyzed: $log_count" >> report.txt
echo "Errors: $error_count" >> report.txt
echo "Warnings: $warning_count" >> report.txt

echo ""
echo "Report generated: report.txt"


# Create backup directory
backup_dir="backups/$timestamp"
mkdir -p "$backup_dir"

# Copy log files to backup directory
cp "$LOG_DIR"/*.log "$backup_dir"

# Compress backup
tar -czf "$backup_dir.tar.gz" "$backup_dir"

echo "Backup created at: $backup_dir"
echo "Compressed backup: $backup_dir.tar.gz"
echo ""
echo "Process completed successfully!"