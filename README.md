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


## Testing Approach

The tool was validated using multiple controlled log scenarios to ensure robustness across real-world conditions.

### Isolated Test Scenarios

Each scenario verifies specific behavior:

- **Clean logs** → validates zero-error handling  
- **Warning-heavy logs** → ensures warning detection  
- **Error-heavy logs** → validates error aggregation  
- **Malformed logs** → confirms resilience to irregular input  
- **Empty directory** → verifies graceful failure  

Run individually:

```bash
./log_tool.sh test_logs/clean
./log_tool.sh test_logs/errors
./log_tool.sh test_logs/malformed
./log_tool.sh test_logs/empty
```

---

### Real-World Simulation

A combined dataset simulates production-like conditions with mixed log patterns.

```bash
./log_tool.sh test_logs/real_world
```

This validates the tool’s ability to process heterogeneous logs at scale.

---

### Key Validation Goals

- Correct error and warning aggregation  
- Case-insensitive parsing  
- Robustness to malformed entries  
- Graceful handling of missing logs  
- Consistent reporting and backup generation  

This approach mirrors unit-style and integration-style testing for CLI utilities.