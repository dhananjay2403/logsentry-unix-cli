<p align="center">
  <h1 align="center">LogSentry Unix CLI</h1>
  <p align="center">
    A reusable Bash CLI for Unix log analysis, reporting, automated backups, and containerized execution.
  </p>
</p>

---

## Installation

```bash
chmod +x install.sh
./install.sh
```

Run from anywhere after install:

```bash
logsentry
logsentry /path/to/logs
```

---

## Docker Usage

Build the Docker image:

```bash
docker build -t logsentry:1.3 .
```

Create host-mounted runtime directories:

```bash
mkdir -p host_logs
mkdir -p host_reports
mkdir -p host_backups
```

Copy sample logs:

```bash
cp logs/*.log host_logs/
```

Run the container:

```bash
docker run \
  -v $(pwd)/host_logs:/data/logs \
  -v $(pwd)/host_reports:/data/reports \
  -v $(pwd)/host_backups:/data/backups \
  logsentry:1.3
```

Generated reports and compressed backups persist on the host machine through Docker bind mounts.

---

## Usage

```bash
logsentry test_logs/real_world
```

---

## Quick options:

```bash
logsentry -h                          # show help
logsentry -d test_logs/mixed_case     # show matching ERROR/WARNING lines with line numbers
logsentry -t 3 test_logs/real_world   # show top 3 most frequent ERROR lines per file
```
---

## Features

- Per-file log analysis with case-insensitive detection of ERROR and WARNING.
- Per-log insights for faster debugging and issue tracing.
- Aggregated summary reporting across production-like log datasets.
- Timestamped report generation for audit-friendly traceability.
- Automated backup snapshots with `.tar.gz` compression.
- Dockerized runtime with bind-mounted persistent reports and backup storage.
- Graceful failure handling for empty or invalid log directories.
- Colorized CLI output for Errors (red), Warnings (yellow), and Success (green).
- Structured test suite covering isolated and production-like scenarios.

---

## Screenshots

<table>
  <tr>
    <td align="center"><b>Run Output (summary)</b></td>
    <td align="center"><b>Run Output (details: -d)</b></td>
    <td align="center"><b>Run Output (top errors: -t 3)</b></td>
  </tr>
  <tr>
    <td align="center">
      <img src="screenshots/run_output.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Run output summary" />
    </td>
    <td align="center">
      <img src="screenshots/run_output_details.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Run output details" />
    </td>
    <td align="center">
      <img src="screenshots/run_top_errors.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Top errors output" />
    </td>
  </tr>

  <tr>
    <td align="center"><b>Generated Report</b></td>
    <td align="center"><b>Persistent Backup Artifacts</b></td>
    <td align="center"><b>Docker Runtime Persistence</b></td>
  </tr>
  <tr>
    <td align="center">
      <img src="screenshots/report_view.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Generated report view" />
    </td>
    <td align="center">
      <img src="screenshots/backup_example.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Backup artifacts example" />
    </td>
    <td align="center">
      <img src="screenshots/docker_runtime.jpg"
           width="100%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Docker runtime persistence" />
    </td>
  </tr>

  <tr>
    <td colspan="3" align="center">
      <b>Help / Flags</b>
    </td>
  </tr>
  <tr>
    <td colspan="3" align="center">
      <img src="screenshots/logsentry_help.jpg"
           width="60%"
           style="border:1px solid #ccc; border-radius:6px;"
           alt="Help flags output" />
    </td>
  </tr>
</table>

---

## Tech Stack

- Bash
- Unix CLI tools (`grep`, `wc`, `tar`, `cp`, `sed`, `sort`, `uniq`)
- Docker
- Git

---


## Testing

This project includes an automated test runner and structured test fixtures to validate behavior across isolated and production-like scenarios.

### Run Full Test Suite

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Scenarios included:

- `test_logs/clean` — clean logs (no errors)
- `test_logs/errors` — error-heavy logs
- `test_logs/warnings` — warning-heavy logs
- `test_logs/malformed` — noisy / malformed logs
- `test_logs/real_world` — production-like combined dataset
- `test_logs/empty` — empty directory (graceful failure)

You can also test specific datasets:

```bash
logsentry test_logs/malformed
logsentry -d test_logs/real_world
logsentry -t 5 test_logs/mixed_case
```

### What the tests validate

- Correct aggregation of ERROR and WARNING entries (case-insensitive)
- Robust handling of malformed or noisy log entries
- Graceful exit when no `.log` files are found
- Automatic report generation
- Timestamped backup creation and compression
- Docker-compatible runtime behavior with persistent mounted storage