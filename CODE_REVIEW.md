# BUMP Code Review - Comprehensive Analysis

## Executive Summary

This review covers security vulnerabilities, bugs, logging/error handling improvements, code style issues, documentation gaps, and inconsistencies between parallel and normal function versions.

**Priority Levels:**
- 🔴 **CRITICAL**: Security vulnerabilities or data loss bugs
- 🟡 **HIGH**: Bugs that affect functionality
- 🟢 **MEDIUM**: Code quality and maintainability improvements
- 🔵 **LOW**: Minor style and documentation improvements

---

## 1. Security Issues

### 🔴 CRITICAL: Potential Command Injection in niceload (parallel.sh:230)

**Location:** `parallel.sh:230`

```bash
niceload -v --load "${an_target_load}" ${OPT_NICELOAD:-} -p "${an_mainid}" &
```

**Issue:** The `${OPT_NICELOAD:-}` variable is expanded without quotes, allowing potential command injection if an attacker can control this environment variable.

**Fix:**
```bash
# Option 1: Quote and validate
niceload -v --load "${an_target_load}" "${OPT_NICELOAD:-}" -p "${an_mainid}" &

# Option 2: Better - validate before use
if [[ -n "${OPT_NICELOAD}" ]]; then
    # Validate contains only safe characters
    if [[ "${OPT_NICELOAD}" =~ ^[a-zA-Z0-9_=-]+$ ]]; then
        niceload -v --load "${an_target_load}" ${OPT_NICELOAD} -p "${an_mainid}" &
    else
        parallel_report 1 "invalid OPT_NICELOAD value"
        return 1
    fi
else
    niceload -v --load "${an_target_load}" -p "${an_mainid}" &
fi
```

---

### 🔴 CRITICAL: Regex Injection in check_contains (bump.sh:209)

**Location:** `bump.sh:209`

```bash
if ! grep -qs "${cc_string}" "${cc_file}"; then
```

**Issue:** If `cc_string` contains regex special characters, it will be interpreted as a regex pattern, potentially matching unintended content or causing errors.

**Fix:**
```bash
if ! grep -qsF "${cc_string}" "${cc_file}"; then
```
Use `-F` flag for fixed string (literal) matching instead of regex.

---

### 🔴 CRITICAL: Unsafe sed Pattern in path_as_name (bump.sh:254)

**Location:** `bump.sh:254`

```bash
echo "$pan_path" | sed -e 's:^/::' -e 's:/:-:g' -e 's/[[:space:]]/_/g'
```

**Issue:** If `pan_path` contains certain characters (like newlines or sed delimiters), it could cause unexpected behavior.

**Fix:**
```bash
# Use bash built-in string manipulation instead
local result="$pan_path"
result="${result#/}"           # Remove leading slash
result="${result//\//-}"       # Replace / with -
result="${result//[[:space:]]/_}"  # Replace spaces with _
echo "$result"
```

---

### 🟡 HIGH: Unvalidated File Write Operations

**Locations:** Multiple functions write to files without validating the directory exists or checking permissions.

**Examples:**
- `load_report` (line 397)
- `memory_report` (line 440)
- `free_memory_report` (line 491)

**Fix:** Add directory validation before writing:
```bash
# In each report function, add before write:
local log_dir
log_dir=$(dirname "${log_file}")
if [[ ! -d "$log_dir" ]]; then
    echo "${STAMP}: log directory $log_dir does not exist" >&2
    return $FILING_ERROR
fi
if [[ ! -w "$log_dir" ]]; then
    echo "${STAMP}: log directory $log_dir is not writable" >&2
    return $SECURITY_FAILURE
fi
```

---

## 2. Bugs and Logic Issues

### 🟡 HIGH: Incorrect Parameter Validation in log_message (bump.sh:109)

**Location:** `bump.sh:109`

```bash
function log_message {
    local ls_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "date stamp" "${ls_message}"  # ← WRONG: should be "message"
    echo "${STAMP}: ${ls_message}" >&2
}
```

**Fix:**
```bash
function log_message {
    local lm_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "message" "${lm_message}"
    echo "${STAMP}: ${lm_message}" >&2
}
```

---

### 🟡 HIGH: Unvalidated Global Variable in poll_reports (bump.sh:529)

**Location:** `bump.sh:529`

```bash
if [[ -f "$ramdisk/workers" ]]; then
```

**Issue:** The `$ramdisk` variable is never validated for emptiness or existence. If not set, this creates a path like `/workers`.

**Fix:**
```bash
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
    # Add this:
    not_empty "ramdisk directory" "${ramdisk}"

    # Also validate it exists
    if [[ -n "${ramdisk}" ]] && [[ ! -d "${ramdisk}" ]]; then
        echo "${STAMP}: ramdisk directory ${ramdisk} does not exist" >&2
        return $MISSING_FOLDER
    fi

    # ... rest of function
}
```

---

### 🟡 HIGH: Fragile Memory Detection Logic (bump.sh:477)

**Location:** `bump.sh:477`

```bash
fmr_available=$(free -m | grep Mem | awk '{print ($7 != "") ? $7 : ($4 + $6)}')
```

**Issue:** Different versions of `free` have different column layouts. This awk expression assumes column 7 exists for "available" memory, but this is not always present.

**Fix:**
```bash
# More robust approach - use free -m with specific output format
if free -m --help 2>&1 | grep -q -- "--si"; then
    # Modern free with --available option
    fmr_available=$(free -m | awk '/^Mem:/ {print $7}')
else
    # Older free - calculate from buffers/cache
    fmr_available=$(free -m | awk '/^-\/\+ buffers\/cache:/ {print $4}')
    if [[ -z "$fmr_available" ]]; then
        # Fallback for even older versions
        fmr_available=$(free -m | awk '/^Mem:/ {print $4}')
    fi
fi

# Validate we got a number
if ! [[ "$fmr_available" =~ ^[0-9]+$ ]]; then
    report 1 "failed to parse available memory"
    return 1
fi
```

---

### 🟡 HIGH: Race Condition in cleanup Function (bump.sh:352-353)

**Location:** `bump.sh:352-353`

```bash
if [[ "$cleanfn" == cleanup_* ]]; then
    if declare -f "$cleanfn" >/dev/null 2>&1; then
```

**Issue:** If a cleanup function is removed between the array check and the `declare -f` check, this could fail. More importantly, if a cleanup function fails and causes the script to exit again, we could get infinite recursion.

**Fix:**
```bash
# Add guard against re-entrance
if [[ -n "${CLEANUP_RUNNING:-}" ]]; then
    echo "${STAMP}: cleanup already running, avoiding recursion" >&2
    exit "${1:-1}"
fi
export CLEANUP_RUNNING=1

local cleanfn
for cleanfn in "${cleanup_functions[@]}"; do
    if [[ "$cleanfn" == cleanup_* ]]; then
        if declare -f "$cleanfn" >/dev/null 2>&1; then
            # Don't let cleanup function failures crash cleanup
            "$cleanfn" "${c_rc}" 2>&1 || {
                local clean_rc=$?
                echo "${STAMP}: cleanup function $cleanfn failed with code $clean_rc" >&2
            }
        else
            echo "${STAMP}: cleanup function $cleanfn not found" >&2
        fi
    else
        echo "${STAMP}: not calling $cleanfn (invalid name)" >&2
    fi
done
```

---

### 🟢 MEDIUM: Inconsistent Return Code Handling in check_md5 (bump.sh:162-188)

**Location:** `bump.sh:162-188`

**Issue:** The function calls `check_exists` which may call `cleanup` and exit. If the test environment prevents exit, execution continues and MD5 checking proceeds on a non-existent file, leading to confusing error messages.

**Fix:**
```bash
function check_md5 {
    local cm_md5="$1"
    local cm_file="$2"
    log_setting "required MD5" "$cm_md5"
    log_setting "file to check" "$cm_file"

    # Check if file exists - but handle the case where check_exists doesn't exit
    if [[ ! -e "$cm_file" ]]; then
        echo "${STAMP}: cannot find $cm_file for MD5 check" >&2
        cleanup "$MISSING_FILE"
        return $MISSING_FILE  # In case cleanup doesn't exit
    fi

    local md5 rc
    md5=$(md5sum "${cm_file}" 2>&1 | awk '{print $1}')
    rc=$?

    if [[ $rc -ne 0 ]]; then
        report $rc "computing md5sum for $cm_file" "cannot verify file integrity"
        return $rc
    fi

    # Validate MD5 format
    if ! [[ "$md5" =~ ^[a-f0-9]{32}$ ]]; then
        report 1 "invalid MD5 format from md5sum: $md5" "cannot verify file integrity"
        return $CORRUPT_DATA
    fi

    log_message "computed MD5: $md5"

    if [[ "$md5" == "${cm_md5}" ]]; then
        echo "${STAMP}: $cm_file has correct md5" >&2
        return 0
    else
        report $CORRUPT_DATA "checking $cm_file" "wrong md5: expected ${cm_md5}, got ${md5}"
        return $CORRUPT_DATA
    fi
}
```

---

### 🟢 MEDIUM: Missing PID Validation in kids Function (parallel.sh:166-168)

**Location:** `parallel.sh:166-168`

**Issue:** PID validation happens but not early enough - should validate before using in paths.

**Fix:**
```bash
function kids {
    local pid="$1"

    parallel_not_empty "pid to check for children" "$pid" || return $?

    # Validate PID is numeric - MOVE THIS UP
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: invalid PID: $pid" >&2
        return 1
    fi

    # Check if /proc is available FIRST
    if [[ ! -d "/proc/$pid" ]]; then
        return 0 # Process doesn't exist, no children
    fi

    # ... rest of function
}
```

---

## 3. Missing Parallel Function Implementations

### 🟡 HIGH: Inconsistent Function Coverage

The `parallel.sh` file is missing parallel-safe versions of many functions from `bump.sh`:

**Missing Functions:**
1. `parallel_check_contains` - should be added
2. `parallel_check_md5` - should be added
3. `parallel_check_dependency` - should be added
4. `parallel_path_as_name` - could be added (though doesn't need parallel safety)
5. `parallel_load_report` - should be added
6. `parallel_memory_report` - should be added
7. `parallel_free_memory_report` - should be added
8. `parallel_slow` - should be added
9. `parallel_log_message` - EXISTS but should verify consistency

**Recommended Additions:**

```bash
# parallel_check_contains: Verify file contains string (parallel-safe)
function parallel_check_contains {
    local file_name="$1"
    local string="$2"
    parallel_log_setting "file name to check" "$file_name"
    parallel_log_setting "string to check for" "$string"

    if [[ -e "$file_name" ]]; then
        if ! grep -qsF "${string}" "${file_name}"; then
            echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${file_name} does not contain ${string}" >&2
            return $BAD_CONFIGURATION
        fi
    else
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cannot find ${file_name}" >&2
        return $MISSING_FILE
    fi
    return 0
}
export -f parallel_check_contains

# parallel_check_dependency: Verify command exists (parallel-safe)
function parallel_check_dependency {
    local cmd="$1"
    parallel_log_setting "command to check for" "${cmd}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        parallel_report ${MISSING_CMD} "looking for ${cmd}"
        return ${MISSING_CMD}
    fi
    return 0
}
export -f parallel_check_dependency

# parallel_check_md5: Verify MD5 checksum (parallel-safe)
function parallel_check_md5 {
    local md5_expected="$1"
    local file="$2"
    parallel_log_setting "required MD5" "$md5_expected"
    parallel_log_setting "file to check" "$file"

    parallel_check_exists "$file" || return $?

    local md5_actual rc
    md5_actual=$(md5sum "${file}" 2>&1 | awk '{print $1}')
    rc=$?

    if [[ $rc -ne 0 ]]; then
        parallel_report $rc "computing md5sum for $file"
        return $rc
    fi

    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: computed MD5: $md5_actual" >&2

    if [[ "$md5_actual" == "${md5_expected}" ]]; then
        echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: $file has correct md5" >&2
        return 0
    else
        parallel_report $CORRUPT_DATA "checking $file: wrong md5"
        return $CORRUPT_DATA
    fi
}
export -f parallel_check_md5
```

---

### 🟡 HIGH: Cleanup Functions Array vs String Inconsistency

**Issue:** `bump.sh` uses an array `cleanup_functions=()` to store multiple cleanup functions, but `parallel.sh` uses a single string variable `parallel_cleanup_function=""`.

**Current parallel.sh (line 118):**
```bash
parallel_cleanup_function=""
```

**Recommendation:** Make parallel.sh consistent with bump.sh:

```bash
# Change to array for consistency
declare -a parallel_cleanup_functions=()

function parallel_cleanup {
    local rc="${1:-0}"
    echo "***" >&2
    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: exiting subprocess cleanly with code ${rc} . . ." >&2

    # Iterate through array like bump.sh does
    local cleanfn
    for cleanfn in "${parallel_cleanup_functions[@]}"; do
        if [[ "$cleanfn" == parallel_cleanup_* ]]; then
            if declare -f "$cleanfn" >/dev/null 2>&1; then
                "$cleanfn" "${rc}" 2>&1 || {
                    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cleanup function $cleanfn failed" >&2
                }
            else
                echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cleanup function $cleanfn not found" >&2
            fi
        else
            echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: not calling $cleanfn (invalid name)" >&2
        fi
    done

    echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: . . . all done with code ${rc}" >&2
    return "$rc"
}
export -f parallel_cleanup
```

---

## 4. Logging and Error Handling Improvements

### 🟢 MEDIUM: Inconsistent Error Reporting

**Issue:** Some functions use direct `echo ... >&2`, others use `report`, and others use `log_message`. This makes it hard to parse logs systematically.

**Recommendation:** Standardize on using `log_message` for info and `report` for errors:

**Example fixes:**

```bash
# In check_exists - instead of:
echo "${STAMP}: cannot find $ce_file_name" >&2
cleanup "$MISSING_FILE"

# Use:
log_message "cannot find $ce_file_name"
cleanup "$MISSING_FILE"
```

---

### 🟢 MEDIUM: Add Log Levels

**Recommendation:** Add log level support for better filtering:

```bash
# Add to bump.sh after line 48:
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR

# Add function:
function log_level {
    local level="$1"
    shift
    local message="$*"

    case "${LOG_LEVEL}" in
        DEBUG) ;;
        INFO) [[ "$level" == "DEBUG" ]] && return ;;
        WARN) [[ "$level" =~ ^(DEBUG|INFO)$ ]] && return ;;
        ERROR) [[ "$level" != "ERROR" ]] && return ;;
    esac

    echo "${STAMP}: [${level}] ${message}" >&2
}
```

---

### 🟢 MEDIUM: Improve report Function Clarity

**Issue:** The `report` function has confusing dual behavior - it sometimes continues and sometimes exits based on the third parameter.

**Current behavior (bump.sh:269-281):**
```bash
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
```

**Recommendation:** Split into two functions for clarity:

```bash
# For non-fatal errors that continue
function report_error {
    local rc="$1"
    local description="$2"
    log_message "${description} returned code $rc (continuing)"
    return "$rc"
}

# For fatal errors that exit
function report_fatal {
    local rc="$1"
    local description="$2"
    local exit_message="${3:-exiting due to error}"
    log_message "${description} exited with code $rc"
    log_message "$exit_message"
    cleanup "$rc"
}

# Keep report for backward compatibility
function report {
    local r_rc="$1"
    local r_description="$2"
    local r_exit_message="$3"
    if [[ -z "$r_exit_message" ]]; then
        report_error "$r_rc" "$r_description"
    else
        report_fatal "$r_rc" "$r_description" "$r_exit_message"
    fi
}
```

---

### 🟢 MEDIUM: Add Error Context Stack

**Recommendation:** Add a context stack to provide better error tracing:

```bash
# Add after line 48
declare -a ERROR_CONTEXT=()

function push_context {
    ERROR_CONTEXT+=("$1")
}

function pop_context {
    unset 'ERROR_CONTEXT[-1]'
}

function log_message {
    local lm_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "message" "${lm_message}"

    # Add context if available
    if [[ ${#ERROR_CONTEXT[@]} -gt 0 ]]; then
        local context="${ERROR_CONTEXT[*]}"
        context="${context// / > }"
        echo "${STAMP}: [${context}] ${lm_message}" >&2
    else
        echo "${STAMP}: ${lm_message}" >&2
    fi
}

# Usage:
# push_context "backup_database"
# push_context "validate_checksums"
# log_message "checking file1.sql"  # Output: [backup_database > validate_checksums] checking file1.sql
# pop_context
```

---

## 5. Code Style Improvements

### 🟢 MEDIUM: Inconsistent Variable Naming Prefixes

**Issue:** Functions use inconsistent prefixes for local variables:
- `not_empty` uses `ne_` prefix
- `log_setting` uses `ls_` prefix
- `check_exists` uses `ce_` prefix
- `check_contains` uses `cc_` prefix
- etc.

While this prevents name collisions, it's inconsistent in application.

**Recommendation:** Either:
1. Use prefixes consistently for ALL local variables, OR
2. Use descriptive names without prefixes (preferred for readability)

**Example refactor:**
```bash
# Current:
function not_empty {
    local ne_description="$1"
    local ne_check="$2"
    if [[ -z "$ne_check" ]]; then
        echo "${STAMP}: cannot run without ${ne_description}" >&2
        cleanup "${MISSING_INPUT}"
    fi
    return 0
}

# Improved (no prefix, descriptive names):
function not_empty {
    local description="$1"
    local value_to_check="$2"
    if [[ -z "$value_to_check" ]]; then
        echo "${STAMP}: cannot run without ${description}" >&2
        cleanup "${MISSING_INPUT}"
    fi
    return 0
}
```

---

### 🟢 MEDIUM: Inconsistent Quoting Style

**Issue:** Mix of single and double quotes where either would work.

**Recommendation:** Follow these rules:
- Use double quotes when variable expansion is needed
- Use single quotes for literal strings
- Always quote variable expansions

---

### 🟢 MEDIUM: Add `set -euo pipefail` Option

**Recommendation:** Consider documenting whether scripts should use:
```bash
set -euo pipefail
```

This would catch more errors but might interact poorly with the cleanup mechanism. Document the recommendation in README.

---

### 🔵 LOW: Inconsistent Function Documentation Format

**Issue:** Most functions have good documentation, but format varies slightly.

**Recommendation:** Standardize on this format:

```bash
# function_name: Brief one-line description
#
# Longer description explaining what the function does,
# any important details about its behavior, side effects,
# or assumptions.
#
# Usage: function_name arg1 arg2
# Args:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Globals:
#   GLOBAL_VAR - Description of global variable used
# Returns:
#   0 on success, ERROR_CODE on failure
# Exits:
#   May call cleanup with EXIT_CODE under condition X
```

---

## 6. Documentation Improvements

### 🟢 MEDIUM: Missing Inline Comments for Complex Logic

Add inline comments for non-obvious logic:

**Example 1 - kids function (parallel.sh:176-187):**
```bash
local t children kid
for t in /proc/${pid}/task/*; do
    # Each process can have multiple threads under /proc/PID/task/
    # Each thread has a 'children' file listing child processes
    children="${t}/children"
    if [[ -e "$children" ]]; then
        while read -r kid; do
            if [[ -n "$kid" ]]; then
                echo "$kid"
                # Recursively find all descendants
                kids "$kid"
            fi
        done < "$children"
    fi
done
```

**Example 2 - cleanup (bump.sh:353):**
```bash
"$cleanfn" "${c_rc}" || true  # Don't let cleanup failures prevent other cleanups
```

---

### 🟢 MEDIUM: Add Examples to Function Documentation

Functions with complex behavior should include usage examples:

```bash
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
# Globals:
#   job - Job name for labeling
#   logs - Directory for log files
#   ramdisk - Directory containing workers file
# Returns: 0 when monitored process terminates
#
# Example:
#   job="backup"
#   logs="/var/log/backup"
#   ramdisk="/dev/shm/backup"
#   poll_reports $$ $$ 30 &  # Monitor current process, poll every 30s
#   MONITOR_PID=$!
```

---

### 🟢 MEDIUM: Document Global Variable Requirements

Create a section at the top of `bump.sh` listing all global variables that functions may expect:

```bash
##  Global Variables Used by Functions
#   STAMP   - Timestamp set by set_stamp, required by most functions
#   MONTH   - Month string set by set_month (format: YYYYMM)
#   WAIT    - Seconds to wait between attempts (default: 5)
#   RULE    - Separator line for formatting (default: "========================================")
#   cleanup_functions - Array of cleanup function names to call on exit
#
##  Global Variables Used by Specific Functions
#   job     - Required by poll_reports: job name for labeling
#   logs    - Required by poll_reports: directory for log files
#   ramdisk - Required by poll_reports: directory for workers file
#   OPT_NICELOAD - Optional for apply_niceload: additional niceload options
```

---

### 🔵 LOW: Add Troubleshooting Section to README

The README has a troubleshooting section, but could add:

1. Common error codes and their meanings
2. How to debug functions that call cleanup
3. How to test functions in isolation
4. Performance considerations for monitoring functions

---

## 7. Test Improvements

### 🟡 HIGH: Missing Tests for Parallel Functions

**Issue:** `test_bump.sh` and `test_bump_advanced.sh` don't test any parallel.sh functions.

**Recommendation:** Create `test_parallel.sh`:

```bash
#!/bin/bash
# test_parallel.sh: Unit tests for parallel.sh functions

script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/return_codes.sh"
. "${script_path}/parallel.sh"

# Set up parallel environment variables
export PARALLEL_PID=$$
export PARALLEL_JOBSLOT=1
export PARALLEL_SEQ=1

# Test parallel_not_empty
# Test parallel_log_setting
# Test parallel_log_message
# Test parallel_check_exists
# Test parallel_report
# Test kids function
# Test apply_niceload (if niceload available)
# etc.
```

---

### 🟢 MEDIUM: Add Integration Tests

Create integration test that tests realistic workflows:

```bash
#!/bin/bash
# test_integration.sh: Integration tests for BUMP

# Test 1: Full backup script workflow
# Test 2: Parallel file processing workflow
# Test 3: Monitoring with cleanup workflow
# Test 4: Error recovery workflow
```

---

### 🟢 MEDIUM: Improve Test Isolation

**Issue:** Tests override `cleanup` function, which is fragile and doesn't truly test cleanup behavior.

**Recommendation:** Use subprocess testing:

```bash
function test_cleanup_behavior {
    test_start "cleanup function behavior"

    # Run in subprocess to test real exit behavior
    local output
    output=$(
        bash -c '
            . ./return_codes.sh
            . ./bump.sh
            set_stamp

            cleanup_called=0
            function cleanup_test {
                echo "cleanup_test called"
                cleanup_called=1
            }
            cleanup_functions+=("cleanup_test")

            cleanup 42
        ' 2>&1
    )
    local exit_code=$?

    assert_equals "42" "$exit_code" "cleanup exits with provided code"
    assert_contains "$output" "cleanup_test called" "cleanup function was called"
}
```

---

## 8. Performance Considerations

### 🟢 MEDIUM: Optimize poll_reports Loop

**Issue:** `poll_reports` reads the workers file and calls `memory_report` for each worker on every iteration, which could be expensive for many workers.

**Recommendation:**

```bash
# Cache worker PIDs and only check for new ones periodically
local -A known_workers=()
local check_counter=0

while kill -0 "$pr_pid_monitor" 2>/dev/null; do
    sleep "${pr_wait}"

    load_report "${job} run" "${logs}/${STAMP}.${job}.${pr_pid_label}.load"

    # Only reread workers file every 10 iterations
    if (( check_counter % 10 == 0 )) && [[ -f "$ramdisk/workers" ]]; then
        local pid
        while read -r pid; do
            pid="${pid%% *}"
            known_workers[$pid]=1
        done < "$ramdisk/workers"
    fi
    check_counter=$((check_counter + 1))

    # Report on known workers
    for pid in "${!known_workers[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            memory_report "${job} run" "${pid}" \
                "${logs}/${STAMP}.${job}.${pid}.memory"
        else
            # Worker terminated, remove from tracking
            unset known_workers[$pid]
        fi
    done

    free_memory_report "${job} run" \
                       "${logs}/${STAMP}.${job}.${pr_pid_label}.free"
done
```

---

### 🔵 LOW: Consider Caching command -v Results

**Issue:** `check_dependency` calls `command -v` which does a PATH search. If called frequently, this could be slow.

**Recommendation:** For scripts that check many dependencies, cache results:

```bash
declare -A CMD_CACHE=()

function check_dependency {
    local cmd="$1"

    # Check cache first
    if [[ -n "${CMD_CACHE[$cmd]}" ]]; then
        return 0
    fi

    log_setting "command to check for is" "${cmd}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        report ${MISSING_CMD} \
               "looking for ${cmd}" \
               "exiting cleanly"
        return ${MISSING_CMD}
    fi

    CMD_CACHE[$cmd]=1
    return 0
}
```

---

## 9. Summary of Recommendations by Priority

### Immediate Action Required (🔴 CRITICAL)

1. Fix command injection in niceload calls
2. Fix regex injection in check_contains
3. Fix unsafe sed in path_as_name
4. Add file write validation

### High Priority (🟡 HIGH)

1. Fix log_message parameter validation bug
2. Fix unvalidated $ramdisk variable
3. Fix fragile memory detection
4. Add guard against cleanup recursion
5. Add missing parallel functions
6. Fix cleanup array inconsistency
7. Add tests for parallel functions

### Medium Priority (🟢 MEDIUM)

1. Standardize error reporting
2. Add log levels
3. Improve report function clarity
4. Fix variable naming consistency
5. Add inline comments
6. Document global variables
7. Add integration tests
8. Optimize poll_reports

### Low Priority (🔵 LOW)

1. Standardize function documentation format
2. Add troubleshooting docs
3. Consider command caching

---

## Conclusion

The BUMP codebase is well-structured with good documentation and test coverage for core functionality. However, there are several security vulnerabilities that should be addressed immediately, along with some bugs and consistency issues between parallel and normal implementations.

The main areas for improvement are:
1. **Security hardening** - input validation and safe command construction
2. **Parallel consistency** - adding missing parallel-safe functions
3. **Error handling** - standardizing patterns and improving clarity
4. **Testing** - adding parallel function tests and integration tests

Implementing these recommendations will make BUMP more robust, secure, and maintainable.
