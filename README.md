# BUMP - Bash Utility Management Package

BUMP is a library for use in bash utilities designed to bring reliability and monitoring capabilities to shell scripts. In system administration and automation, bash scripts often start simple but grow more complex as they handle edge cases, errors, and resource constraints. 
BUMP transforms fragile bash scripts into robust applications. BUMP provides error handling, system monitoring, and process management capabilities for shell scripts. It includes support for sequential and parallel execution using GNU Parallel.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Components](#components)
- [Usage Guide](#usage-guide)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)

## Overview

### Why BUMP?

Modern system administrators and automation engineers face several challenges when writing bash scripts:

- **Error Handling**: bash scripts can fail silently or with cryptic errors. BUMP provides standardized exit codes and error reporting, making debugging and monitoring significantly easier.

- **Resource Management**: Production environments demand careful resource ise. BUMP includes monitoring for CPU load, memory usage, and process states, allowing scripts to adapt to system conditions.

- **Parallel Execution**: As data volumes grow and systems scale, sequential processing becomes a bottleneck. BUMP integrates with [GNU Parallel](https://www.gnu.org/software/parallel/), for concurrent execution while maintaining consistent error handling and resource tracking across parallel jobs.

- **Signal Handling and Process Management**: Graceful shutdown is crucial for maintaining data integrity. BUMP provides robust signal handling and cleanup mechanisms, ensuring that interrupted scripts leave systems in a clean state.

### Applications

BUMP excels in three primary domains:

**1. System Maintenance and Monitoring**

System administrators use BUMP to create reliable maintenance scripts that:
- Perform rolling backups with automatic verification and cleanup
- Monitor service health with intelligent alerting thresholds  
- Automate log rotation with resource-aware compression
- Manage disk space with safe cleanup of old files

**2. Data Pipeline Management**

Data engineers leverage BUMP for building resilient ETL pipelines that:
- Process large datasets with automatic parallelization
- Handle network interruptions with retry logic
- Track resource consumption across pipeline stages

**3. Scientific Batch Processing**

Researchers and HPC users benefit from BUMP's capabilities for:
- Managing long-running simulations with checkpoint/restart functionality
- Distributing computational workloads across available cores
- Monitoring memory usage to prevent out-of-memory failures
- Generating performance metrics for optimization

### Features

- **Standardized Exit Codes**: Consistent error codes across all scripts
- **Automatic Cleanup**: Register cleanup functions that run on exit
- **Resource Validation**: Check for files, directories, and dependencies
- **System Monitoring**: Track CPU load, memory usage, and process states
- **Parallel Execution**: Safe versions of functions for use with GNU Parallel
- **Signal Handling**: Graceful handling of interrupts and termination signals
- **Timestamp Management**: Consistent timestamp generation for logs and files

### How It Works

BUMP follows the Unix philosophy of composable tools. Scripts source the BUMP libraries to gain access to a set of functions:

```bash
#!/bin/bash
script_path=$(dirname $(realpath $0))
. ${script_path}/bump/return_codes.sh
. ${script_path}/bump/bump.sh

# Your script now has access to robust error handling, monitoring, and more
```

This approach means existing scripts can be enhanced with BUMP features without complete rewrites.

### Design Philosophy

- **Fail Fast, Fail Clearly**: Errors are detected early and reported with meaningful messages and standardized exit codes
- **Resource Awareness**: Scripts should adapt to system conditions rather than blindly consuming resources
- **Defensive Programming**: Every operation that can fail is checked, logged, and handled appropriately
- **Composability**: Functions work independently and can be combined to build complex workflows

## Getting Started


## Installation

1. Clone the repository or copy the bump directory to your project:
```bash
git clone https://github.com/yourusername/bump.git
# or
cp -r /path/to/bump /your/project/
```

2. Ensure the scripts are executable:
```bash
chmod +x bump/*.sh
```

## Quick Start

For system administrators familiar with bash scripting, BUMP offers immediate value with minimal learning curve. The library's functions follow predictable patterns and integrate naturally with existing bash idioms. Advanced users can leverage the parallel execution capabilities to scale their scripts across multiple cores or even distributed systems.

This README provides comprehensive documentation, practical examples, and best practices developed from years of production use in high-stakes environments. Whether you're automating routine maintenance tasks or building complex data processing pipelines, BUMP helps you write bash scripts that are reliable, maintainable, and performant.

For more information about bash scripting fundamentals, see the [GNU Bash manual](https://www.gnu.org/software/bash/manual/). For examples of bash scripts in HPC environments, refer to [Swinburne's HPC documentation](https://supercomputing.swin.edu.au/docs/) which demonstrates many patterns that BUMP was designed to support.

Basic usage in your bash script:

```bash
#!/bin/bash
# Get the directory where your script is located
script_path=$(dirname "$(readlink -f "$0")")

# Source the bump utilities
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"

# Initialize timestamp
set_stamp

# Set up signal handling
trap handle_signal SIGINT SIGTERM

# Your script logic here
check_exists "/path/to/required/file"
check_dependency "rsync"

# Script will exit cleanly on error or signal
```

## Components

### 1. return_codes.sh
Defines standardized exit codes for consistent error reporting:

- **60-69**: Missing resources (files, folders, commands)
- **70-79**: Configuration and safety issues  
- **80-89**: System and infrastructure failures
- **110-119**: Signal handling codes

### 2. bump.sh
Core utility functions including:

- **Initialization**: `set_stamp`, `set_month`
- **Validation**: `not_empty`, `check_exists`, `check_contains`, `check_dependency`
- **Logging**: `log_setting`, `report`, `print_rule`
- **Cleanup**: `cleanup`, `handle_signal`
- **Monitoring**: `load_report`, `memory_report`, `free_memory_report`, `poll_reports`
- **Utilities**: `path_as_name`, `slow`

### 3. parallel.sh
GNU Parallel-safe versions of core functions:

- `parallel_not_empty` - Validate non-empty values
- `parallel_log_message` - Log simple messages
- `parallel_log_setting` - Log configuration values
- `parallel_report` - Report errors without exiting
- `parallel_check_exists` - Verify file/directory exists
- `parallel_cleanup` - Execute cleanup for a parallel job
- `kids` - Find all child processes
- `apply_niceload` - Apply load limiting to process trees

## Usage Guide

### Setting Up Your Script

```bash
#!/bin/bash
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"

# Initialize
set_stamp
WAIT=10  # Set wait time for slow function
RULE="======================================"

# Set up cleanup
cleanup_functions+=("cleanup_my_resources")

function cleanup_my_resources {
    local rc=$1
    echo "Cleaning up resources with exit code $rc" >&2
    # Your cleanup code here
}

# Set up signal handling
trap handle_signal SIGINT SIGTERM
```

### Validating Resources

```bash
# Check required files and directories
check_exists "/etc/passwd"
check_exists "/var/log"

# Check required commands
check_dependency "git"
check_dependency "docker"

# Validate parameters
not_empty "username" "$1"
not_empty "config file" "$CONFIG_FILE"

# Check file contents
check_contains "/etc/hosts" "localhost"
```

### Error Handling

```bash
# Report errors without exiting
some_command || report $? "running some_command"

# Report errors and exit with cleanup
critical_command || report $? "critical operation failed" "exiting due to critical failure"

# Manual cleanup with specific exit code
cleanup $MISSING_FILE
```

### System Monitoring

```bash
# Monitor system load
load_report "build_start" "/var/log/myapp/load.log"

# Monitor process memory
memory_report "worker" $$ "/var/log/myapp/memory.log"

# Monitor available memory
free_memory_report "system" "/var/log/myapp/free.log"

# Continuous monitoring
poll_reports $main_pid $$ 30 &  # Poll every 30 seconds
```

### Using with GNU Parallel

```bash
#!/bin/bash
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/parallel.sh"

# Export required variables
export STAMP
export -f process_file

function process_file {
    local file=$1
    parallel_check_exists "$file" || return $?
    parallel_log_setting "processing" "$file"
    
    # Process the file
    if ! some_processing "$file"; then
        parallel_report $? "processing $file"
        return $?
    fi
    
    parallel_cleanup 0
}

# Run in parallel
find /data -name "*.txt" | parallel -j 4 process_file
```

## API Reference

### Core Functions

#### Initialization Functions

- **set_stamp**: Generate a timestamp for the session
  ```bash
  set_stamp  # Sets $STAMP to YYYYMMDDTHHMMSS-hostname
  ```

- **set_month**: Set current year-month
  ```bash
  set_month  # Sets $MONTH to YYYYMM
  ```

#### Validation Functions

- **not_empty**: Ensure a value is not empty
  ```bash
  not_empty "description" "$value"
  ```

- **check_exists**: Verify file/directory exists
  ```bash
  check_exists "/path/to/file"
  ```

- **check_contains**: Check file contains string
  ```bash
  check_contains "/etc/config" "required_setting"
  ```

- **check_dependency**: Verify command exists
  ```bash
  check_dependency "docker"
  ```

- **check_md5**: Verify file checksum
  ```bash
  check_md5 "d41d8cd98f00b204e9800998ecf8427e" "/path/to/file"
  ```

#### Logging Functions

- **log_message**: Log a simple message
  ```bash
  log_message "starting database backup"
  ```

- **log_setting**: Log a configuration value
  ```bash
  log_setting "database host" "$DB_HOST"
  ```

- **report**: Report an error (with optional exit)
  ```bash
  report $? "operation failed"  # Continue
  report $? "critical failure" "exiting"  # Exit via cleanup
  ```

#### System Monitoring

- **load_report**: Record system load
  ```bash
  load_report "phase1" "/logs/load.log"
  ```

- **memory_report**: Record process memory
  ```bash
  memory_report "worker" $PID "/logs/memory.log"
  ```

- **free_memory_report**: Record available memory
  ```bash
  free_memory_report "checkpoint" "/logs/free.log"
  ```

- **poll_reports**: Continuous monitoring
  ```bash
  poll_reports $monitor_pid $label_pid $interval
  ```

### Parallel Functions

All parallel functions follow the same pattern as core functions but:
- Return error codes instead of calling cleanup
- Include GNU Parallel job identifiers in output (PARALLEL_PID, PARALLEL_JOBSLOT, PARALLEL_SEQ)
- Are exported for use in subshells

## Examples

### Example 1: File Processing Script

```bash
#!/bin/bash
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"

set_stamp
trap handle_signal SIGINT SIGTERM

# Validate inputs
not_empty "input directory" "$1"
not_empty "output directory" "$2"

INPUT_DIR="$1"
OUTPUT_DIR="$2"

# Check directories
check_exists "$INPUT_DIR"
[ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR"

# Check dependencies
check_dependency "imagemagick"
check_dependency "exiftool"

# Process files
for file in "$INPUT_DIR"/*.jpg; do
    [ -f "$file" ] || continue
    
    basename=$(basename "$file")
    log_setting "processing" "$basename"
    
    convert "$file" -resize 800x600 "$OUTPUT_DIR/$basename" || \
        report $? "converting $basename"
done

cleanup 0
```

### Example 2: System Backup Script

```bash
#!/bin/bash
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"

set_stamp
set_month

# Configuration
BACKUP_ROOT="/backup"
SOURCE_DIRS=("/etc" "/home" "/var/www")
BACKUP_DIR="$BACKUP_ROOT/$MONTH"

# Cleanup function
cleanup_functions+=("cleanup_backup")
function cleanup_backup {
    local rc=$1
    if [ -f "/tmp/backup.lock" ]; then
        rm -f "/tmp/backup.lock"
    fi
}

trap handle_signal SIGINT SIGTERM

# Create lock file
if [ -f "/tmp/backup.lock" ]; then
    report $UNSAFE "backup already running" "exiting"
fi
touch "/tmp/backup.lock"

# Validate environment
check_exists "$BACKUP_ROOT"
check_dependency "rsync"
check_dependency "tar"

# Create backup directory
mkdir -p "$BACKUP_DIR" || report $? "creating backup directory" "cannot continue"

# Start monitoring
poll_reports $$ $$ 60 > "$BACKUP_DIR/system_stats.log" 2>&1 &
MONITOR_PID=$!

# Backup each directory
for dir in "${SOURCE_DIRS[@]}"; do
    check_exists "$dir"
    
    archive_name="$(path_as_name "$dir").tar.gz"
    log_setting "backing up" "$dir to $archive_name"
    
    tar czf "$BACKUP_DIR/$archive_name" "$dir" 2>/dev/null || \
        report $? "backing up $dir"
done

# Stop monitoring
kill $MONITOR_PID 2>/dev/null

# Wait for rsync processes to finish
slow "rsync"

cleanup 0
```

### Example 3: Parallel Data Processing

```bash
#!/bin/bash
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"
. "${script_path}/bump/parallel.sh"

set_stamp
export STAMP

# Define processing function
function process_data_file {
    local file=$1
    
    parallel_check_exists "$file" || return $?
    
    # Simulate processing
    parallel_log_setting "processing" "$file"
    sleep $((RANDOM % 5))
    
    # Simulate occasional failure
    if [ $((RANDOM % 10)) -eq 0 ]; then
        parallel_report 1 "random failure for $file"
        return 1
    fi
    
    parallel_log_setting "completed" "$file"
    return 0
}
export -f process_data_file

# Find and process files in parallel
log_setting "starting parallel processing" "using 8 jobs"

find /data -name "*.csv" -type f | \
    parallel -j 8 --halt soon,fail=10% process_data_file

rc=$?
if [ $rc -ne 0 ]; then
    report $rc "parallel processing" "some jobs failed"
fi

cleanup 0
```

## Best Practices

1. **Always Initialize Timestamps**: Call `set_stamp` early in your script
2. **Set Up Signal Handling**: Use `trap handle_signal SIGINT SIGTERM`
3. **Register Cleanup Functions**: Add cleanup functions to `cleanup_functions` array
4. **Use Consistent Error Codes**: Use the predefined codes from return_codes.sh
5. **Check Dependencies Early**: Validate all requirements before starting work
6. **Quote Variables**: Always quote variables to handle spaces and special characters
7. **Export for Parallel**: Export functions and variables when using GNU Parallel
8. **Monitor Long Operations**: Use poll_reports for operations that take significant time

## Requirements

- **Bash**: Version 4.0 or higher
- **GNU Core Utilities**: Standard Unix utilities (grep, sed, awk)
- **procfs**: /proc filesystem (for monitoring functions)
- **GNU Parallel**: (Optional) For parallel execution support
- **niceload**: (Optional) Part of GNU Parallel, for load limiting

### Platform Support

- **Linux**: Full support for all features
- **macOS**: Limited support (some monitoring features require procfs)
- **WSL**: Full support when procfs is available

## Troubleshooting

### Common Issues

1. **"cannot find return_codes.sh"**
   - Ensure bump directory is in the correct location relative to your script
   - Check that files have read permissions

2. **Monitoring functions return errors**
   - These functions require Linux procfs (/proc)
   - Some features may not work on macOS or other Unix systems

3. **Signal handling not working**
   - Ensure you've called `trap handle_signal SIGINT SIGTERM`
   - Some environments may block certain signals

4. **Parallel functions not found**
   - Make sure to export functions with `export -f function_name`
   - Source parallel.sh in addition to bump.sh

### Debug Mode

Enable verbose output for debugging:

```bash
#!/bin/bash
set -x  # Enable trace mode
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/bump/return_codes.sh"
. "${script_path}/bump/bump.sh"
set +x  # Disable trace mode for your script
```

## Contributing

When contributing to bump:

1. Maintain backward compatibility
2. Follow existing naming conventions
3. Add parallel-safe versions for new functions
4. Use standardized return codes
5. Include comprehensive function documentation
6. Test on multiple platforms

## License

See LICENSE file in the repository root.
