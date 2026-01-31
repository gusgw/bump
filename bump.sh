#!/bin/bash
##  Utility functions
#
#   This library provides common utility functions for bash scripts, including
#   logging, error handling, file verification, and resource monitoring.
#
#   Usage:
#     source bump.sh
#     set_stamp
#     log_message "Starting script..."

##  Settings
#   STAMP   should be set by a call to set_stamp in this file.
#   WAIT    is the time to wait in seconds between repeated attempts.
#   RULE    is a separator to use in formatting outputs.

VERSION="1.1.0"

##  Notes
#   Run set_stamp and set_month before using the other routines.

# Return codes: Standardized exit codes for bump utility scripts
# Exit Code Ranges:
#   60-69: Missing resources (files, commands, etc.)
#   70-79: Configuration and safety issues
#   80-89: System and infrastructure failures
#   110-119: Signal handling

# Missing Resources (60-69)
# These codes indicate that a required resource could not be found
MISSING_INPUT=60      # Required input parameter was not provided
MISSING_FILE=61       # Required file does not exist
MISSING_FOLDER=62     # Required directory does not exist
MISSING_DISK=63       # Required disk or device not available
MISSING_MOUNT=64      # Required mount point not mounted
MISSING_CMD=65        # Required command not found in PATH

# Configuration and data Issues (70-79)
# These codes indicate problems with configuration or data or safety checks
BAD_CONFIGURATION=70  # Configuration file or setting is invalid
UNSAFE=71             # Operation deemed unsafe to proceed
CORRUPT_DATA=72       # Not continuing due to corrupt data

# System Failures (80-89)
# These codes indicate system-level failures
SYSTEM_UNIT_FAILURE=80  # Systemd unit or service failure
SECURITY_FAILURE=81     # Security check or permission failure
NETWORK_ERROR=83        # Network connectivity or remote resource failure
FILING_ERROR=84         # Error from routine file management

# Signal Handling (110-119)
# These codes are used when handling system signals
TRAPPED_SIGNAL=113    # Generic trapped signal (SIGINT, SIGTERM, etc.)
SHUTDOWN_SIGNAL=114   # Graceful shutdown signal received

# Set default values for global variables
WAIT=${WAIT:-5}
RULE=${RULE:-"========================================"}

# set_stamp: Generate a timestamp for labeling files and messages
#
# Creates a timestamp in the format YYYYMMDDTHHMMSS-hostname
# The timestamp is exported as the global variable STAMP
#
# Usage: set_stamp
# Example:
#   set_stamp
#   echo $STAMP  # Output: 20231114T120000-myhost
# Returns: 0 on success
function set_stamp {
    # Use hostname command as fallback if hostnamectl is not available
    local ss_hostname
    if command -v hostname >/dev/null 2>&1; then
        ss_hostname=$(hostname)
    elif [ -f /etc/hostname ]; then
        ss_hostname=$(cat /etc/hostname)
    else
        ss_hostname="${HOSTNAME:-unknown}"
    fi
    export STAMP="$(date '+%Y%m%dT%H%M%S')-${ss_hostname}"
    return 0
}

# set_month: Set a global variable containing the current year and month
#
# Creates a YYYYMM formatted string for use in folder naming
# The month is exported as the global variable MONTH
#
# Usage: set_month
# Example:
#   set_month
#   echo $MONTH  # Output: 202311
# Returns: 0 on success
function set_month {
    export MONTH="$(date '+%Y%m')"
    return 0
}

# not_empty: Validate that a value is not empty
#
# Checks if the provided value is non-empty. If empty, prints an error
# message and calls cleanup with MISSING_INPUT exit code.
#
# Usage: not_empty "description" "value"
# Example:
#   not_empty "username" "$USER"
# Args:
#   $1 - Description of the value being checked
#   $2 - The value to check
# Returns: 0 if not empty, calls cleanup with MISSING_INPUT if empty
function not_empty {
    local ne_description="$1"
    local ne_check="$2"
    if [[ -z "$ne_check" ]]; then
        echo "${STAMP}: cannot run without ${ne_description}" >&2
        cleanup "${MISSING_INPUT}"
    fi
    return 0
}

# soft_not_empty: Check that a value is not empty (non-fatal)
#
# Non-fatal variant of not_empty. Returns an error code instead of
# calling cleanup, so the calling script can handle the failure.
# Suitable for use in if/then conditional logic.
#
# Usage: soft_not_empty "description" "$value"
# Example:
#   if soft_not_empty "config file" "$config"; then
#       echo "config is set"
#   else
#       echo "config is missing, using default"
#   fi
# Args:
#   $1 - Description of the value being checked
#   $2 - The value to check
# Returns: 0 if not empty, MISSING_INPUT (60) if empty
function soft_not_empty {
    local sne_description="$1"
    local sne_check="$2"
    if [[ -z "$sne_check" ]]; then
        echo "${STAMP}: cannot run without ${sne_description}" >&2
        return ${MISSING_INPUT}
    fi
    return 0
}

# log_message: Log a timestamped message to stderr
#
# Outputs a message prefixed with the global STAMP timestamp to stderr.
# Validates that both STAMP and the message are non-empty before logging.
#
# Usage: log_message "message to log"
# Example:
#   log_message "Backup started successfully"
# Args:
#   $1 - Message to log
# Returns: 0 on success
function log_message {
    local lm_message="$1"
    not_empty "message" "${lm_message}"
    not_empty "date stamp" "${STAMP}"
    echo "${STAMP}: ${lm_message}" >&2
}


# log_setting: Log a setting value to stderr
#
# Validates that both the setting and STAMP are non-empty, then logs
# the setting description and value to stderr.
#
# Usage: log_setting "description" "value"
# Example:
#   log_setting "backup directory" "/var/backups"
# Args:
#   $1 - Description of the setting
#   $2 - The setting value
# Returns: 0 on success
function log_setting {
    local ls_description="$1"
    local ls_setting="$2"
    not_empty "date stamp" "${STAMP}"
    not_empty "$ls_description" "$ls_setting"
    echo "${STAMP}: ${ls_description} is ${ls_setting}" >&2
    return 0
}

# check_exists: Verify that a file, directory, or link exists
#
# Checks if the specified path exists. If not, prints an error message
# and calls cleanup with MISSING_FILE exit code.
#
# Usage: check_exists "/path/to/file"
# Example:
#   check_exists "/etc/passwd"
# Args:
#   $1 - Path to check for existence
# Returns: 0 if exists, calls cleanup with MISSING_FILE if not
function check_exists {
    local ce_file_name="$1"
    log_setting "file or directory name that must exist" "$ce_file_name"
    if [[ ! -e "$ce_file_name" ]]; then
        echo "${STAMP}: cannot find $ce_file_name" >&2
        cleanup "$MISSING_FILE"
    fi
    return 0
}

# soft_check_exists: Check that a file or directory exists (non-fatal)
#
# Non-fatal variant of check_exists. Returns an error code instead of
# calling cleanup, so the calling script can handle the failure.
# Suitable for use in if/then conditional logic.
#
# Usage: soft_check_exists "/path/to/check"
# Example:
#   if soft_check_exists "/etc/myapp.conf"; then
#       source "/etc/myapp.conf"
#   else
#       echo "Using defaults"
#   fi
# Args:
#   $1 - Path to check for existence
# Returns: 0 if exists, MISSING_FILE (61) if not
function soft_check_exists {
    local sce_file_name="$1"
    log_setting "file or directory name that must exist" "$sce_file_name"
    if [[ ! -e "$sce_file_name" ]]; then
        echo "${STAMP}: cannot find $sce_file_name" >&2
        return ${MISSING_FILE}
    fi
    return 0
}

# check_md5: Verify the MD5 checksum of a file
#
# Computes the MD5 checksum of the specified file and compares it
# to the expected value. Reports success or failure.
#
# Usage: check_md5 "expected_md5" "/path/to/file"
# Example:
#   check_md5 "d41d8cd98f00b204e9800998ecf8427e" "/tmp/empty_file"
# Args:
#   $1 - Expected MD5 checksum
#   $2 - Path to file to check
# Returns: 0 on success, CORRUPT_DATA on checksum mismatch
function check_md5 {
    local cm_md5="$1"
    local cm_file="$2"
    log_setting "required MD5" "$cm_md5"
    log_setting "file to check" "$cm_file"

    # Check if file exists (return error code instead of exiting for consistency)
    if [[ ! -e "$cm_file" ]]; then
        report $MISSING_FILE "cannot find $cm_file"
        return $MISSING_FILE
    fi

    local cm_actual_md5 cm_rc
    cm_actual_md5=$(md5sum "${cm_file}" | awk '{print $1}')
    cm_rc=$?

    if [[ $cm_rc -ne 0 ]]; then
        report $cm_rc "computing md5sum for $cm_file"
        return $cm_rc
    fi

    echo "$cm_actual_md5" >&2

    if [[ "$cm_actual_md5" == "${cm_md5}" ]]; then
        echo "${STAMP}: $cm_file has correct md5" >&2
        return 0
    else
        report $CORRUPT_DATA "checking $cm_file, wrong md5"
        return $CORRUPT_DATA
    fi
}

# check_contains: Verify that a file exists and contains a specific string
#
# Checks if the file exists and contains the specified string as a literal match
# (not as a regex pattern). Calls cleanup with appropriate exit code on failure.
#
# Usage: check_contains "/path/to/file" "search_string"
# Example:
#   check_contains "/var/log/syslog" "error"
# Args:
#   $1 - Path to file to check
#   $2 - Literal string to search for in the file
# Returns: 0 if file exists and contains string, calls cleanup on failure
function check_contains {
    local cc_file_name="$1"
    local cc_string="$2"
    log_setting "file name to check" "$cc_file_name"
    log_setting "string to check for" "$cc_string"
    not_empty "date stamp" "$STAMP"

    if [[ -e "$cc_file_name" ]]; then
        if ! grep -qsF "${cc_string}" "${cc_file_name}"; then
            report "$BAD_CONFIGURATION" "${cc_file_name} does not contain ${cc_string}" "exiting cleanly"
        fi
    else
        report "$MISSING_FILE" "cannot find ${cc_file_name}" "exiting cleanly"
    fi
    return 0
}

# check_dependency: Verify that a command is available in PATH
#
# Checks if the specified command exists in the system PATH.
# Calls report with MISSING_CMD exit code if not found.
#
# Usage: check_dependency "command_name"
# Example:
#   check_dependency "rsync"
# Args:
#   $1 - Name of the command to check
# Returns: 0 if command exists, calls report with MISSING_CMD if not
function check_dependency {
    local cd_cmd="$1"
    log_setting "command to check for is" "${cd_cmd}"
    if ! command -v "${cd_cmd}" >/dev/null 2>&1; then
        report ${MISSING_CMD} \
               "looking for ${cd_cmd}" \
               "exiting cleanly"
        return ${MISSING_CMD}
    fi
    return 0
}

# path_as_name: Convert a file path to a safe filename
#
# Converts a path to a string suitable for use as a filename by:
# - Removing leading slash
# - Replacing slashes with hyphens
# - Replacing spaces with underscores
#
# Usage: name=$(path_as_name "/path/to/file")
# Example:
#   path_as_name "/var/log/syslog" # Output: var-log-syslog
# Args:
#   $1 - Path to convert
# Returns: 0 on success, outputs converted name to stdout
function path_as_name {
    local pan_path="$1"
    not_empty "path to convert to a name" "$pan_path"

    # Use bash built-in string manipulation (safer than sed with special chars)
    local pan_result="$pan_path"
    pan_result="${pan_result#/}"           # Remove leading slash
    pan_result="${pan_result//\//-}"       # Replace / with -
    pan_result="${pan_result//[[:space:]]/_}"  # Replace spaces with _

    echo "$pan_result"
    return 0
}

# report: Report an error with optional cleanup
#
# Reports a non-zero return code with description.
# - If exit_message ($3) IS provided: Logs error, calls cleanup, and EXITS the script.
# - If exit_message ($3) is NOT provided: Logs error and CONTINUES execution.
#
# Usage:
#   report 1 "operation failed"                 # Log and continue
#   report 1 "critical failure" "exiting now"   # Log and exit
#
# Args:
#   $1 - Return code
#   $2 - Description of what failed
#   $3 - (Optional) Exit message - causes script termination
# Returns: The provided return code (if not exiting)
function report {
    local r_rc="$1"
    local r_description="$2"
    local r_exit_message="$3"
    echo "${STAMP}: ${r_description} exited with code $r_rc" >&2
    if [[ -z "$r_exit_message" ]]; then
        echo "${STAMP}: continuing . . ." >&2
    else
        echo "${STAMP}: $r_exit_message" >&2
        cleanup "$r_rc"
    fi
    return "$r_rc"
}

# slow: Wait for all processes with given name to terminate
#
# Monitors running processes by name and waits for them to complete.
# Useful for ensuring processes like rsync have fully terminated.
# Uses global WAIT variable for sleep interval (default 5 seconds).
#
# Usage: slow "process_name"
# Example:
#   slow "rsync"
# Args:
#   $1 - Name of the process to wait for
# Returns: 0 when all matching processes have terminated
function slow {
    local s_pname="$1"
    log_setting "program name to wait for" "$s_pname"
    local s_pid
    local s_pids=$(pgrep -x -u "$(id -u)" "$s_pname")
    for s_pid in $s_pids; do
        while kill -0 "$s_pid" 2>/dev/null; do
            echo "${STAMP}: ${s_pname} ${s_pid} is still running" >&2
            sleep "${WAIT}"
        done
    done
    return 0
}

# print_rule: Print a separator line to stdout
#
# Prints the global RULE variable as a visual separator.
# Default rule is a line of equals signs.
#
# Usage: print_rule
# Example:
#   print_rule  # Outputs: ========================================
# Returns: 0 on success
function print_rule {
    echo "$RULE"
}

# print_error_rule: Print a separator line to stderr
#
# Prints the global RULE variable as a visual separator to stderr.
# Default rule is a line of equals signs.
#
# Usage: print_error_rule
# Example:
#   print_error_rule >&2
# Returns: 0 on success
function print_error_rule {
    echo "$RULE" >&2
}

cleanup_functions=()

# cleanup: Execute cleanup functions and exit with specified code
#
# Runs all registered cleanup functions in order, then exits.
# Cleanup functions must have names starting with "cleanup_".
# Can be used as a signal handler.
#
# WARNING: If using the report function here, do not use
#          a third argument! If you do you will get an
#          infinite loop.
#
# Usage: cleanup exit_code
# Example:
#   # Define cleanup function
#   function cleanup_temp_files { rm -rf "$TEMP_DIR"; }
#   cleanup_functions+=("cleanup_temp_files")
#
#   # Call cleanup on error
#   cleanup 1
# Args:
#   $1 - Exit code to use when exiting
# Returns: Does not return - exits with provided code
function cleanup {
    local c_rc="${1:-0}"

    # Prevent recursion
    if [[ -n "${CLEANUP_RUNNING:-}" ]]; then
        echo "${STAMP}: cleanup already running, preventing recursion" >&2
        return "$c_rc"
    fi
    export CLEANUP_RUNNING=1

    print_error_rule
    echo "${STAMP}: exiting cleanly with code ${c_rc}. . ." >&2

    local cleanfn
    for cleanfn in "${cleanup_functions[@]}"; do
        if [[ "$cleanfn" == cleanup_* ]]; then
            if declare -f "$cleanfn" >/dev/null 2>&1; then
                "$cleanfn" "${c_rc}" || true
            else
                echo "${STAMP}: cleanup function $cleanfn not found" >&2
            fi
        else
            echo "${STAMP}: not calling $cleanfn (invalid name)" >&2
        fi
    done
    echo "${STAMP}: . . . all done with code ${c_rc}" >&2
    exit "$c_rc"
}

# handle_signal: Signal handler that calls cleanup
#
# Used as a trap handler for signals. Logs the signal and calls
# cleanup with TRAPPED_SIGNAL exit code.
#
# Usage: trap handle_signal SIGINT SIGTERM
# Returns: Does not return - calls cleanup which exits
function handle_signal {
    echo "${STAMP}: trapped signal" >&2
    cleanup "${TRAPPED_SIGNAL}"
}

# load_report: Record system load average to a file
#
# Appends current system load (1, 5, 15 minute averages) with timestamp
# to the specified file. Uses /proc/loadavg on Linux systems.
#
# Usage: load_report "label" "/path/to/load.log"
# Example:
#   load_report "backup_job" "/var/log/backup_load.log"
# Args:
#   $1 - Label to prefix the load data
#   $2 - Path to file where load data should be appended
# Returns: 0 on success, non-zero on failure
function load_report {
    local lr_label="$1"
    local lr_load_file="$2"
    local rc

    not_empty "label" "$lr_label"
    not_empty "load log file" "$lr_load_file"

    # Validate log file directory before attempting to write
    local log_dir
    log_dir=$(dirname "${lr_load_file}")
    if [[ ! -d "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir does not exist" >&2
        return $FILING_ERROR
    fi
    if [[ ! -w "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir is not writable" >&2
        return $SECURITY_FAILURE
    fi

    if [[ ! -f /proc/loadavg ]]; then
        echo "${STAMP}: /proc/loadavg not available" >&2
        return 1
    fi

    echo "${lr_label} $(date -Ins) $(awk '{print $1" "$2" "$3}' /proc/loadavg)" >> "${lr_load_file}"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "saving system load"
    fi
    return $rc
}

# memory_report: Record process memory usage to a file
#
# Captures peak memory (VmHWM) and current memory (VmRSS) usage for
# a specific process and appends to a log file.
#
# Usage: memory_report "label" pid "/path/to/memory.log"
# Example:
#   memory_report "backup_job" $$ "/var/log/backup_memory.log"
# Args:
#   $1 - Label to prefix the memory data
#   $2 - Process ID to monitor
#   $3 - Path to file where memory data should be appended
# Returns: 0 on success, 1 if process not found, other non-zero on error
function memory_report {
    local mr_label="$1"
    local mr_pid="$2"
    local mr_memory_file="$3"
    local mr_VmHWM mr_VmRSS rc

    not_empty "label" "$mr_label"
    not_empty "pid" "$mr_pid"
    not_empty "memory log file" "$mr_memory_file"

    # Validate log file directory before attempting to write
    local log_dir
    log_dir=$(dirname "${mr_memory_file}")
    if [[ ! -d "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir does not exist" >&2
        return $FILING_ERROR
    fi
    if [[ ! -w "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir is not writable" >&2
        return $SECURITY_FAILURE
    fi

    if [[ ! -f "/proc/${mr_pid}/status" ]]; then
        return 1 # process not found
    fi

    mr_VmHWM=$(grep VmHWM "/proc/${mr_pid}/status" | awk '{print $2}')
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "finding VmHWM"
        return $rc
    fi

    mr_VmRSS=$(grep VmRSS "/proc/${mr_pid}/status" | awk '{print $2}')
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "finding VmRSS"
        return $rc
    fi

    echo "${mr_label} ${mr_pid} $(date -Ins) ${mr_VmHWM} ${mr_VmRSS}" >> "${mr_memory_file}"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "saving memory usage"
    fi
    return $rc
}

# free_memory_report: Record system memory availability to a file
#
# Captures available memory and free swap space in megabytes and
# appends to a log file with timestamp.
#
# Usage: free_memory_report "label" "/path/to/memory.log"
# Example:
#   free_memory_report "system_status" "/var/log/system_memory.log"
# Args:
#   $1 - Label to prefix the memory data
#   $2 - Path to file where memory data should be appended
# Returns: 0 on success, non-zero on failure
function free_memory_report {
    local fmr_label="$1"
    local fmr_file="$2"
    local fmr_total fmr_available fmr_swap_free rc

    not_empty "label" "$fmr_label"
    not_empty "memory log file" "$fmr_file"

    # Validate log file directory before attempting to write
    local log_dir
    log_dir=$(dirname "${fmr_file}")
    if [[ ! -d "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir does not exist" >&2
        return $FILING_ERROR
    fi
    if [[ ! -w "$log_dir" ]]; then
        echo "${STAMP}: log directory $log_dir is not writable" >&2
        return $SECURITY_FAILURE
    fi

    # Check if free command is available
    if ! command -v free >/dev/null 2>&1; then
        echo "${STAMP}: free command not available" >&2
        return 1
    fi

    fmr_total=$(free -m | grep Mem | awk '{print $2}')
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "finding total memory"
        return $rc
    fi

    # Column 7 might not exist in all versions of free, use available or free+buffers/cache
    fmr_available=$(free -m | grep Mem | awk '{print ($7 != "") ? $7 : ($4 + $6)}')
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "finding available memory"
        return $rc
    fi

    fmr_swap_free=$(free -m | grep Swap | awk '{print $4}')
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "finding free swap space"
        return $rc
    fi

    echo "${fmr_label} $(date -Ins) ${fmr_available} ${fmr_swap_free}" >> "${fmr_file}"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        report $rc "saving free memory"
    fi
    return $rc
}

# poll_reports: Continuously monitor and log system resources
#
# Polls system load, process memory, and free memory at regular intervals
# while a monitored process is running. Logs data to specified files.
# Requires global variables: job, logs, ramdisk
#
# Usage: poll_reports monitor_pid label_pid wait_seconds
# Example:
#   job="backup"; logs="/var/log"; ramdisk="/tmp"
#   long_running_process &
#   pid=$!
#   poll_reports $pid "job_label" 60 &
# Args:
#   $1 - PID to monitor (loop continues while this process runs)
#   $2 - PID or label to use in log filenames
#   $3 - Seconds to wait between polling cycles
# Returns: 0 when monitored process terminates
function poll_reports {
    local pr_pid_monitor="$1"
    local pr_pid_label="$2"
    local pr_wait="$3"

    not_empty "PID to monitor in loop condition" "$pr_pid_monitor"
    not_empty "PID to use for labelling resource reports" "$pr_pid_label"
    not_empty "time between reports" "$pr_wait"

    # Validate required global variables
    not_empty "job name" "${job}"
    not_empty "logs directory" "${logs}"
    not_empty "ramdisk directory" "${ramdisk}"

    # Monitor loop: continues while the monitored process is running
    # kill -0 checks if process exists without sending actual signal
    while kill -0 "$pr_pid_monitor" 2>/dev/null; do
        sleep "${pr_wait}"

        # Log system load for the main job
        load_report "${job} run" "${logs}/${STAMP}.${job}.${pr_pid_label}.load"

        # Log memory usage for all worker processes (if tracking file exists)
        # Workers file format: "PID description" (one per line)
        if [[ -f "$ramdisk/workers" ]]; then
            local pr_pid
            while read -r pr_pid; do
                # Extract PID from line (in case line has "PID description" format)
                pr_pid="${pr_pid%% *}"
                # Only log memory if worker process still exists
                if kill -0 "${pr_pid}" 2>/dev/null; then
                    memory_report "${job} run" "${pr_pid}" \
                        "${logs}/${STAMP}.${job}.${pr_pid}.memory"
                fi
            done < "$ramdisk/workers"
        fi

        # Log free memory for the system
        free_memory_report "${job} run" \
                           "${logs}/${STAMP}.${job}.${pr_pid_label}.free"
    done
    return 0
}
