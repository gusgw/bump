#!/bin/bash
# parallel.sh: GNU Parallel-safe versions of bump.sh functions
#
# This file provides parallel-safe implementations of bump utility functions
# for use with GNU Parallel. Functions use PARALLEL_* environment variables
# for proper job identification and avoid calling cleanup() which would exit
# the entire parallel session.
#
# Usage: Source after return_codes.sh
#   . /path/to/return_codes.sh
#   . /path/to/parallel.sh
#
# GNU Parallel provides these environment variables:
#   PARALLEL_PID     - PID of the parallel process
#   PARALLEL_JOBSLOT - Job slot number (1 to number of jobs)
#   PARALLEL_SEQ     - Job sequence number

# parallel_not_empty: Validate that a value is not empty (parallel-safe)
# 
# Parallel-safe version of not_empty. Returns error code instead of
# calling cleanup to avoid terminating the entire parallel session.
# 
# Usage: parallel_not_empty "description" "value"
# Args:
#   $1 - Description of the value being checked
#   $2 - The value to check
# Returns: 0 if not empty, MISSING_INPUT if empty
function parallel_not_empty {
    local description="$1"
    local check="$2"
    if [[ -z "$check" ]]; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: missing ${description}" >&2
        return $MISSING_INPUT
    fi
    return 0
}
export -f parallel_not_empty


# parallel_log_setting: Log a setting value to stderr (parallel-safe)
# 
# Parallel-safe version of log_setting. Includes parallel job identifiers
# in the output for better tracking of concurrent jobs.
# 
# Usage: parallel_log_setting "description" "value"
# Args:
#   $1 - Description of the setting
#   $2 - The setting value
# Returns: 0 on success, MISSING_INPUT if parameters are empty
function parallel_log_setting {
    local description="$1"
    local setting="$2"
    parallel_not_empty "date stamp" "${STAMP}" || return $?
    parallel_not_empty "$description" "$setting" || return $?
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${description} is ${setting}" >&2
    return 0
}
export -f parallel_log_setting

# parallel_log_message: Log a timestamped message to stderr (parallel-safe)
# 
# Parallel-safe version of log_message. Includes parallel job identifiers
# in the output for better tracking of concurrent jobs.
# 
# Usage: parallel_log_message "message to log"
# Args:
#   $1 - Message to log
# Returns: 0 on success, MISSING_INPUT if parameters are empty
function parallel_log_message {
    local message="$1"
    parallel_not_empty "date stamp" "${STAMP}" || return $?
    parallel_not_empty "message" "${message}" || return $?
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${message}" >&2
    return 0
}
export -f parallel_log_message

# parallel_report: Report an error without exiting (parallel-safe)
# 
# Parallel-safe version of report. Always continues execution rather
# than calling cleanup, to avoid terminating the parallel session.
# 
# Usage: parallel_report return_code "description"
# Args:
#   $1 - Return code
#   $2 - Description of what failed
# Returns: The provided return code
function parallel_report {
    local rc="$1"
    local description="$2"
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${description} exited with code $rc" >&2
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: continuing . . ." >&2
    return "$rc"
}
export -f parallel_report

# parallel_check_exists: Verify file/directory exists (parallel-safe)
# 
# Parallel-safe version of check_exists. Returns error code instead
# of calling cleanup on failure.
# 
# Usage: parallel_check_exists "/path/to/file"
# Args:
#   $1 - Path to check for existence
# Returns: 0 if exists, MISSING_FILE if not
function parallel_check_exists {
    local file_name="$1"
    parallel_log_setting "file or directory name that must exist" "$file_name"
    if [[ ! -e "$file_name" ]]; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cannot find $file_name" >&2
        return $MISSING_FILE
    fi
    return 0
}
export -f parallel_check_exists

# Global variable for parallel cleanup function
parallel_cleanup_function=""

# parallel_cleanup: Execute cleanup for a parallel job
# 
# Parallel-safe cleanup that returns an exit code rather than calling
# exit. Can run a single cleanup function if registered.
# 
# Usage: parallel_cleanup exit_code
# Args:
#   $1 - Exit code to return
# Returns: The provided exit code (does not exit)
function parallel_cleanup {
    local rc="${1:-0}"
    echo "***" >&2
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: exiting subprocess cleanly with code ${rc} . . ." >&2
    
    if [[ -n "$parallel_cleanup_function" ]]; then
        if [[ "$parallel_cleanup_function" == parallel_cleanup_* ]]; then
            if declare -f "$parallel_cleanup_function" >/dev/null 2>&1; then
                "$parallel_cleanup_function" "${rc}" || true
            else
                echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cleanup function $parallel_cleanup_function not found" >&2
            fi
        else
            echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: not calling $parallel_cleanup_function (invalid name)" >&2
        fi
    fi
    
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: . . . all done with code ${rc}" >&2
    return "$rc"
}
export -f parallel_cleanup

# kids: Recursively find all child processes of a PID
# 
# Traverses /proc filesystem to find all descendant processes.
# Returns one PID per line. Linux-specific (requires /proc).
# 
# Usage: kids parent_pid
# Args:
#   $1 - Parent process ID
# Returns: 0 on success, outputs child PIDs to stdout
function kids {
    local pid="$1"
    
    parallel_not_empty "pid to check for children" "$pid" || return $?
    
    # Validate PID is numeric to prevent injection attacks
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: invalid PID: \"$pid\"" >&2
        return 1
    fi

    # Check if process exists via /proc filesystem
    if [[ ! -d "/proc/$pid" ]]; then
        return 0 # Process doesn't exist, no children
    fi

    # Traverse process tree: each process may have multiple threads (tasks)
    # and each task can have children. We check all tasks to find all descendants.
    local t children kid
    for t in /proc/${pid}/task/*; do
        children="${t}/children"
        if [[ -e "$children" ]]; then
            # Read child PIDs from the children file (one PID per line)
            while read -r kid; do
                if [[ -n "$kid" ]]; then
                    echo "$kid"            # Output this child PID
                    kids "$kid"            # Recursively find its children
                fi
            done < "$children"
        fi
    done

    return 0
}
export -f kids

# apply_niceload: Apply load limiting to a process and its children
# 
# Uses GNU niceload to limit system load caused by a process tree.
# Tracks controlled processes in a file to avoid duplicate control.
# Requires niceload command and optional OPT_NICELOAD global variable.
# 
# Usage: apply_niceload main_pid workers_file target_load
# Args:
#   $1 - Main process ID to control
#   $2 - File path to store controlled PIDs
#   $3 - Target system load limit
# Returns: 0 on success
function apply_niceload {
    local an_mainid="$1"
    local an_workers="$2"
    local an_target_load="$3"

    parallel_not_empty "top level pid for niceload" "${an_mainid}" || return $?
    parallel_not_empty "file to store the pids of the workers" "${an_workers}" || return $?
    parallel_not_empty "target system load" "${an_target_load}" || return $?

    # Check if niceload is available
    if ! command -v niceload >/dev/null 2>&1; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: niceload command not found" >&2
        return $MISSING_CMD
    fi

    # Validate OPT_NICELOAD to prevent command injection
    # Only allow safe niceload options: alphanumeric, hyphens, equals, underscores
    if [[ -n "${OPT_NICELOAD:-}" ]]; then
        if ! [[ "${OPT_NICELOAD}" =~ ^[a-zA-Z0-9_=-]+$ ]]; then
            echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: invalid OPT_NICELOAD value (contains unsafe characters)" >&2
            return 1
        fi
    fi

    # Ensure workers file directory exists
    local workers_dir
    workers_dir=$(dirname "$an_workers")
    if [[ ! -d "$workers_dir" ]]; then
        mkdir -p "$workers_dir" || return $?
    fi

    # Apply niceload to main process if not already controlled
    if ! grep -qs "^${an_mainid} " "${an_workers}" 2>/dev/null; then
        echo "${an_mainid} main job" >> "${an_workers}"
        if [[ -n "${OPT_NICELOAD:-}" ]]; then
            niceload -v --load "${an_target_load}" ${OPT_NICELOAD} -p "${an_mainid}" &
        else
            niceload -v --load "${an_target_load}" -p "${an_mainid}" &
        fi
        parallel_log_setting "main process under load control" "${an_mainid}"
    fi

    # Apply niceload to all child processes
    local an_kid
    for an_kid in $(kids "${an_mainid}"); do
        if ! grep -qs "^${an_kid} " "${an_workers}" 2>/dev/null; then
            echo "${an_kid} child job" >> "${an_workers}"
            if [[ -n "${OPT_NICELOAD:-}" ]]; then
                niceload -v --load "${an_target_load}" ${OPT_NICELOAD} -p "${an_kid}" &
            else
                niceload -v --load "${an_target_load}" -p "${an_kid}" &
            fi
            parallel_log_setting "a process under load control" "${an_kid}"
        fi
    done
    return 0
}
export -f apply_niceload
