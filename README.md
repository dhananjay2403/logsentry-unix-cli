# LogSentry Unix CLI

A Bash-based command-line tool that analyzes log files, generates reports, and creates automated backups.

## Features

- Counts ERROR and WARNING entries across logs
- Generates timestamped analysis report
- Creates backup snapshots of logs
- Compresses backups for storage
- Gracefully handles missing log files

## Tech Used

- Bash scripting
- Unix CLI tools (grep, wc, tar, cp)
- macOS Unix environment

## Usage

```bash
chmod +x log_tool.sh
./log_tool.sh
```

## Screenshots

### CLI Tool Execution
![Run Output](screenshots/run_output.jpg)

### Generated Report
![Report View](screenshots/report_view.jpg)

### Project Structure
![Project Structure](screenshots/project_structure.jpg)

### Backup Artifacts
![Backup Example](screenshots/backup_example.jpg)


---

## Testing

This project includes an automated test runner and structured test fixtures to validate behavior across isolated and real-world scenarios.

### Run the full test suite

```bash
chmod +x run_tests.sh
./run_tests.sh
```

The test runner executes multiple scenarios and prints a compact summary for each:

- test_logs/clean — clean logs (no errors)
- test_logs/errors — error-heavy logs
- test_logs/warnings — warning-heavy logs (if present)
- test_logs/malformed — noisy / malformed logs
- test_logs/real_world — combined production-like dataset
- test_logs/empty — empty directory (graceful failure)

Run a single directory manually
```bash
chmod +x log_tool.sh
./log_tool.sh test_logs/real_world
```

You can also analyze any custom directory containing .log files:
```bash
./log_tool.sh /path/to/your/logs
```

For example: Real-World Simulation - A combined dataset simulates production-like conditions with mixed log patterns.

```bash
./log_tool.sh test_logs/real_world
```

What the tests validate
- Correct aggregation of ERROR and WARNING entries (case-insensitive)
- Robust handling of malformed or noisy log entries
- Graceful exit when no log files are found
- Automatic report generation (report.txt)
- Timestamped backup creation and compression (backups/)

---