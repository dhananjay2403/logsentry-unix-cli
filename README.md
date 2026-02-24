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