#!/bin/bash
##  Utility functions

##  Settings
#   STAMP   should be set by a call to set_stamp in this file.
#   WAIT    is the time to wait in seconds between repeated attempts.
#   RULE    is a separator to use in formatting outputs.

##  Dependencies
#   return_codes.sh

##  Notes
#   Run set_stamp and set_month before using the other routines.

# Get the script path - using readlink for better portability
script_path=$(dirname "$(readlink -f "$0")")
# Source return codes - check if file exists first
if [[ -f "${script_path}/bump/return_codes.sh" ]]; then
    . "${script_path}/bump/return_codes.sh"
elif [[ -f "${script_path}/return_codes.sh" ]]; then
    . "${script_path}/return_codes.sh"
else
    echo "ERROR: Cannot find return_codes.sh" >&2
    exit 1
fi

# Set default values for global variables
WAIT=${WAIT:-5}
RULE=${RULE:-"========================================"}

# set_stamp: Generate a timestamp for labeling files and messages
# 
# Creates a timestamp in the format YYYYMMDDTHHMMSS-hostname
# The timestamp is exported as the global variable STAMP
# 
# Usage: set_stamp
# Returns: 0 on success
function set_stamp {
    # Use hostname command as fallback if hostnamectl is not available
    local hostname
    hostname=$(hostname)
    export STAMP="$(date '+%Y%m%dT%H%M%S')-${hostname}"
    return 0
}

# set_month: Set a global variable containing the current year and month
# 
# Creates a YYYYMM formatted string for use in folder naming
# The month is exported as the global variable MONTH
# 
# Usage: set_month
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

# log_message: Log a timestamped message to stderr
# 
# Outputs a message prefixed with the global STAMP timestamp to stderr.
# Validates that both STAMP and the message are non-empty before logging.
# 
# Usage: log_message "message to log"
# Args:
#   $1 - Message to log
# Returns: 0 on success
function log_message {
    local ls_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "date stamp" "${ls_message}"
    echo "${STAMP}: ${ls_message}" >&2
}


# log_setting: Log a setting value to stderr
# 
# Validates that both the setting and STAMP are non-empty, then logs
# the setting description and value to stderr.
# 
# Usage: log_setting "description" "value"
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

# check_md5: Verify the MD5 checksum of a file
# 
# Computes the MD5 checksum of the specified file and compares it
# to the expected value. Reports success or failure.
# 
# Usage: check_md5 "expected_md5" "/path/to/file"
# Args:
#   $1 - Expected MD5 checksum
#   $2 - Path to file to check
# Returns: 0 on success, CORRUPT_DATA on checksum mismatch
function check_md5 {
    local cm_md5="$1"
    local cm_file="$2"
    log_setting "required MD5" "$cm_md5"
    log_setting "file to check" "$cm_file"
    
    # Check if file exists using check_exists
    check_exists "$cm_file"
    
    local md5 rc
    md5=$(md5sum "${cm_file}" | awk '{print $1}')
    rc=$?
    
    if [[ $rc -ne 0 ]]; then
        report $rc "computing md5sum for $cm_file"
        return $rc
    fi
    
    echo "$md5" >&2
    
    if [[ "$md5" == "${cm_md5}" ]]; then
        echo "${STAMP}: $cm_file has correct md5" >&2
        return 0
    else
        report $CORRUPT_DATA "checking $cm_file" "wrong md5"
        return $CORRUPT_DATA
    fi
}

# check_contains: Verify that a file exists and contains a specific string
# 
# Checks if the file exists and contains the specified string.
# Calls cleanup with appropriate exit code on failure.
# 
# Usage: check_contains "/path/to/file" "search_string"
# Args:
#   $1 - Path to file to check
#   $2 - String to search for in the file
# Returns: 0 if file exists and contains string, calls cleanup on failure
function check_contains {
    local cc_file_name="$1"
    local cc_string="$2"
    log_setting "file name to check" "$cc_file_name"
    log_setting "string to check for" "$cc_string"
    not_empty "date stamp" "$STAMP"
    
    if [[ -e "$cc_file_name" ]]; then
        if ! grep -qs "${cc_string}" "${cc_file_name}"; then
            echo "${STAMP}: ${cc_file_name} does not contain ${cc_string}" >&2
            cleanup "$BAD_CONFIGURATION"
        fi
    else
        echo "${STAMP}: cannot find ${cc_file_name}" >&2
        cleanup "$MISSING_FILE"
    fi
    return 0
}

# check_dependency: Verify that a command is available in PATH
# 
# Checks if the specified command exists in the system PATH.
# Calls report with MISSING_CMD exit code if not found.
# 
# Usage: check_dependency "command_name"
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
# Args:
#   $1 - Path to convert
# Returns: 0 on success, outputs converted name to stdout
function path_as_name {
    local pan_path="$1"
    not_empty "path to convert to a name" "$pan_path"
    echo "$pan_path" | sed -e 's:^/::' -e 's:/:-:g' -e 's/[[:space:]]/_/g'
    return 0
}

# report: Report an error with optional cleanup
# 
# Reports a non-zero return code with description. If exit_message is
# provided, calls cleanup to exit. Otherwise continues execution.
# 
# Usage: report 1 "operation failed" ["exit message"]
# Args:
#   $1 - Return code
#   $2 - Description of what failed
#   $3 - (Optional) Exit message - if provided, cleanup is called
# Returns: The provided return code
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
# Args:
#   $1 - Name of the process to wait for
# Returns: 0 when all matching processes have terminated
function slow {
    local s_pname="$1"
    log_setting "program name to wait for" "$s_pname"
    local pid
    for pid in $(pgrep "$s_pname"); do
        while kill -0 "$pid" 2>/dev/null; do
            echo "${STAMP}: ${s_pname} ${pid} is still running" >&2
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
# Args:
#   $1 - Exit code to use when exiting
# Returns: Does not return - exits with provided code
function cleanup {
    local c_rc="${1:-0}"
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
# Args:
#   $1 - Label to prefix the load data
#   $2 - Path to file where load data should be appended
# Returns: 0 on success, non-zero on failure
function load_report {
    local lr_label="$1"
    local lr_load_file="$2"
    local rc
    
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
# Args:
#   $1 - Label to prefix the memory data
#   $2 - Path to file where memory data should be appended
# Returns: 0 on success, non-zero on failure
function free_memory_report {
    local fmr_label="$1"
    local fmr_file="$2"
    local fmr_total fmr_available fmr_swap_free rc
    
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
    
    while kill -0 "$pr_pid_monitor" 2>/dev/null; do
        sleep "${pr_wait}"
        
        load_report "${job} run" "${logs}/${STAMP}.${job}.${pr_pid_label}.load"
        
        if [[ -f "$ramdisk/workers" ]]; then
            local pid
            while read -r pid; do
                # Extract just the PID if line contains more data
                pid="${pid%% *}"
                if kill -0 "${pid}" 2>/dev/null; then
                    memory_report "${job} run" "${pid}" \
                        "${logs}/${STAMP}.${job}.${pid}.memory"
                fi
            done < "$ramdisk/workers"
        fi
        
        free_memory_report "${job} run" \
                           "${logs}/${STAMP}.${job}.${pr_pid_label}.free"
    done
    return 0
}
