<p align="center">
  <h1 align="center">LogSentry Unix CLI</h1>
  <p align="center">
    A reusable Bash CLI for Unix log analysis, reporting, automated backups, and containerized execution.
  </p>
  <p align="center">
    <a href="https://github.com/dhananjay2403/logsentry-unix-cli/actions/workflows/ci.yml">
      <img src="https://github.com/dhananjay2403/logsentry-unix-cli/actions/workflows/ci.yml/badge.svg" alt="CI status" />
    </a>
    <img src="https://img.shields.io/badge/ShellCheck-clean-brightgreen" alt="ShellCheck clean" />
    <img src="https://img.shields.io/badge/bash-3.2%2B-blue" alt="bash 3.2+" />
    <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT license" />
  </p>
</p>

---

## Installation

```bash
chmod +x install.sh
./install.sh                        # installs to /usr/local/bin (uses sudo if needed)
PREFIX="$HOME/.local" ./install.sh  # user-local install, no sudo
```

Run from anywhere after install:

```bash
logsentry
logsentry /path/to/logs
logsentry --version
```

Remove it again with `./uninstall.sh` (pass the same `PREFIX` you installed with).

---

## Docker Usage

### Pull from Docker Hub

```bash
docker pull dhananjaytiwari/logsentry:1.3
```

---

### Build Locally

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
logsentry                                              # analyse ./logs
logsentry tests/fixtures/realistic/microservices_sim   # analyse any directory
```

---

## Quick options

```bash
logsentry -h                                     # show help
logsentry -V                                     # show version
logsentry -d tests/fixtures/mixed_case           # show matching ERROR/WARNING lines with line numbers
logsentry -t 3 tests/fixtures/errors             # show top 3 most frequent ERROR lines per file
logsentry --top-errors=3 tests/fixtures/errors   # same as -t 3
```

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `LOG_DIR` | `logs` | Directory to analyse when no argument is given |
| `REPORT_DIR` | `reports` | Where the summary report is written |
| `BACKUP_ROOT` | `backups` | Where `.tar.gz` backup archives are written |

### Exit status

| Code | Meaning |
|---|---|
| `0` | Analysis completed |
| `1` | Usage error, missing directory, or no `.log` files found |

---

## Features

- Per-file log analysis with case-insensitive detection of ERROR and WARNING.
- Per-log insights for faster debugging and issue tracing.
- Aggregated summary across every `.log` file in a directory.
- Summary report recording the run timestamp, directory analysed, and totals.
- Timestamped `.tar.gz` backup archives, created straight from the source logs.
- Dockerized runtime with bind-mounted persistent reports and backup storage.
- Graceful failure handling for empty or invalid log directories, with errors on stderr.
- Colorized CLI output for Errors (red), Warnings (yellow), and Success (green) — disabled automatically when output is redirected.
- Dependency-free test suite (35 assertions) plus ShellCheck and Docker checks in CI.
- Runs on macOS (bash 3.2) and Linux without modification.

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

- Bash (3.2-compatible)
- Unix CLI tools (`grep`, `sed`, `sort`, `uniq`, `tar`, `date`, `basename`)
- Docker
- GitHub Actions, ShellCheck
- Git

---


## Testing

```bash
./tests/test_logsentry.sh
```

The suite is plain Bash — no framework to install — and every case asserts a real
value, so it fails loudly when behaviour regresses. It writes reports and archives
to a temporary directory, never into the repository.

Fixtures live in `tests/fixtures/`:

| Fixture | Contents |
|---|---|
| `clean/` | Only INFO lines (0 errors, 0 warnings) |
| `errors/` | Two files, 5 ERROR lines total, including a repeated line for `-t` |
| `warnings/` | 3 WARNING lines |
| `mixed_case/` | `error` / `Error` / `ERROR` and `warning` / `WARNING` |
| `malformed/` | Junk and unstructured lines around 1 ERROR and 1 WARNING |
| `empty/` | No `.log` files (graceful-failure path) |
| `realistic/` | Apache access log, JSON lines, multi-service logs, noisy log — regenerate with `./scripts/generate_demo_logs.sh` |

### What the tests validate

- Per-file and aggregate ERROR/WARNING counts, including mixed-case levels
- Filenames containing spaces
- `LOG_DIR`, `REPORT_DIR`, and `BACKUP_ROOT` overrides
- Exit code `1` with a clear message for a missing directory, a directory with no
  logs, a non-numeric `-t`, and an unknown option
- `-d`, `-t N`, `--top-errors=N`, `--help`, and `--version` output
- Report contents, and that archives contain plain file names with no staging copy
  left behind

### Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and pull request:

- **ShellCheck** (`-S style`) over every script — zero findings
- **Tests** on `ubuntu-latest` and `macos-latest` (bash 5 and bash 3.2)
- **Docker** build plus a container run against the sample logs
