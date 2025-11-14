# BUMP Issues Summary - Complete List

**Source:** CODE_REVIEW.md
**Total Issues Identified:** 33+

---

## Overview

CODE_REVIEW.md documents **33+ issues** across security, bugs, and code quality.

**test_regression.sh** currently tests **7 of these** (the ones with clear, reproducible test cases).

---

## Issue Breakdown by Priority

### 🔴 CRITICAL Security Issues (4 total)

#### 1. Command Injection in apply_niceload
**File:** parallel.sh:230
**Status:** ✅ Has regression test (may skip if niceload unavailable)
**Issue:** Unquoted `${OPT_NICELOAD:-}` variable allows command injection
```bash
# CURRENT (vulnerable):
niceload -v --load "${an_target_load}" ${OPT_NICELOAD:-} -p "${an_mainid}" &

# SHOULD BE (safe):
# Option 1: Quote it
niceload -v --load "${an_target_load}" "${OPT_NICELOAD:-}" -p "${an_mainid}" &

# Option 2: Validate before use
if [[ -n "${OPT_NICELOAD}" ]]; then
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

#### 2. Regex Injection in check_contains
**File:** bump.sh:209
**Status:** ✅ Has regression test
**Issue:** grep without -F flag treats string as regex instead of literal
```bash
# CURRENT (vulnerable):
if ! grep -qs "${cc_string}" "${cc_file_name}"; then

# SHOULD BE (safe):
if ! grep -qsF "${cc_string}" "${cc_file_name}"; then
```
**Impact:** Attacker-controlled strings like `.*`, `^$`, `[a-z]` are treated as regex patterns

---

#### 3. Unsafe sed in path_as_name
**File:** bump.sh:254
**Status:** ✅ Has regression test
**Issue:** sed can break with special characters (colons, newlines, backslashes)
```bash
# CURRENT (unsafe):
echo "$pan_path" | sed -e 's:^/::' -e 's:/:-:g' -e 's/[[:space:]]/_/g'

# SHOULD BE (safe - use bash built-ins):
local result="$pan_path"
result="${result#/}"           # Remove leading slash
result="${result//\//-}"       # Replace / with -
result="${result//[[:space:]]/_}"  # Replace spaces with _
echo "$result"
```

---

#### 4. Unvalidated File Write Operations
**File:** Multiple locations (load_report:397, memory_report:440, free_memory_report:491)
**Status:** ❌ No regression test yet
**Issue:** Functions write to files without checking if directory exists or is writable
```bash
# ADD to each report function:
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

### 🟡 HIGH Priority Bugs (12 total)

#### 5. Wrong Parameter Validation in log_message
**File:** bump.sh:109
**Status:** ✅ Has regression test
**Issue:** Validates "date stamp" twice instead of validating "message"
```bash
# CURRENT (wrong):
function log_message {
    local ls_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "date stamp" "${ls_message}"  # ← WRONG
    echo "${STAMP}: ${ls_message}" >&2
}

# SHOULD BE (correct):
function log_message {
    local lm_message="$1"
    not_empty "date stamp" "${STAMP}"
    not_empty "message" "${lm_message}"  # ← CORRECT
    echo "${STAMP}: ${lm_message}" >&2
}
```

---

#### 6. Unvalidated $ramdisk in poll_reports
**File:** bump.sh:529
**Status:** ✅ Has regression test
**Issue:** Uses `$ramdisk` without checking if empty, creates path "/workers" if unset
```bash
# ADD validation at start of poll_reports:
not_empty "ramdisk directory" "${ramdisk}"

# Also validate it exists:
if [[ -n "${ramdisk}" ]] && [[ ! -d "${ramdisk}" ]]; then
    echo "${STAMP}: ramdisk directory ${ramdisk} does not exist" >&2
    return $MISSING_FOLDER
fi
```

---

#### 7. Fragile Memory Detection in free_memory_report
**File:** bump.sh:477
**Status:** ✅ Has regression test (passes in some environments)
**Issue:** Assumes column 7 exists, but different `free` versions have different layouts
```bash
# CURRENT (fragile):
fmr_available=$(free -m | grep Mem | awk '{print ($7 != "") ? $7 : ($4 + $6)}')

# SHOULD BE (robust):
# Detect free version and use appropriate column
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

#### 8. Race Condition in cleanup Function
**File:** bump.sh:352-353
**Status:** ✅ Has regression test (test includes guard to demonstrate fix)
**Issue:** No guard against re-entrance, could cause infinite recursion
```bash
# ADD at start of cleanup function:
if [[ -n "${CLEANUP_RUNNING:-}" ]]; then
    echo "${STAMP}: cleanup already running, avoiding recursion" >&2
    exit "${1:-1}"
fi
export CLEANUP_RUNNING=1

# MODIFY cleanup function execution:
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

#### 9. Inconsistent Return Code Handling in check_md5
**File:** bump.sh:162-188
**Status:** ❌ No regression test (complex scenario)
**Issue:** Calls check_exists which may exit, leading to confusing error flow
```bash
# IMPROVE by adding explicit file check:
function check_md5 {
    local cm_md5="$1"
    local cm_file="$2"
    log_setting "required MD5" "$cm_md5"
    log_setting "file to check" "$cm_file"

    # Check if file exists - explicit check
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

#### 10. Missing PID Validation in kids Function
**File:** parallel.sh:166-168
**Status:** ❌ No regression test (mostly works)
**Issue:** PID validation happens but not early enough
```bash
# IMPROVE by moving validation earlier:
function kids {
    local pid="$1"

    parallel_not_empty "pid to check for children" "$pid" || return $?

    # Validate PID is numeric - MOVE THIS UP (before using in paths)
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

#### 11-19. Missing Parallel Function Implementations (9 functions!)
**Status:** ❌ No regression tests (would need to add functions first)
**Issue:** parallel.sh is missing parallel-safe versions of many bump.sh functions

**Missing Functions:**
1. `parallel_check_contains` - verify file contains string
2. `parallel_check_md5` - verify file checksum
3. `parallel_check_dependency` - verify command exists
4. `parallel_path_as_name` - convert path to safe filename (may not need parallel version)
5. `parallel_load_report` - record system load
6. `parallel_memory_report` - record process memory
7. `parallel_free_memory_report` - record available memory
8. `parallel_slow` - wait for processes
9. (verify `parallel_log_message` exists and is consistent)

**Implementation Pattern:**
- Don't call `cleanup()` - return error codes instead
- Include `PARALLEL_PID`, `PARALLEL_JOBSLOT`, `PARALLEL_SEQ` in output
- Export with `export -f function_name`
- Use `parallel_report` instead of `report`
- Use `parallel_not_empty`, `parallel_log_setting`, etc.

See CODE_REVIEW.md section 3 for example implementations.

---

#### 20. Cleanup Array vs String Inconsistency
**File:** parallel.sh:118
**Status:** ❌ No regression test
**Issue:** bump.sh uses array, parallel.sh uses string
```bash
# CURRENT (parallel.sh):
parallel_cleanup_function=""  # Single string

# SHOULD BE (consistent with bump.sh):
declare -a parallel_cleanup_functions=()  # Array

# UPDATE parallel_cleanup function to iterate like bump.sh does:
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

### 🟢 MEDIUM Priority Improvements (13+)

#### 21. Inconsistent Error Reporting
**Issue:** Mix of direct `echo >&2`, `report()`, and `log_message()`
**Fix:** Standardize on using `log_message` for info and `report` for errors

---

#### 22. Add Log Levels
**Issue:** No way to filter logs by severity
**Fix:** Add LOG_LEVEL support (DEBUG, INFO, WARN, ERROR)
```bash
LOG_LEVEL="${LOG_LEVEL:-INFO}"

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

#### 23. Improve report Function Clarity
**Issue:** Dual behavior (continue vs exit) based on third parameter is confusing
**Fix:** Split into `report_error()` and `report_fatal()`, keep `report()` for compatibility

---

#### 24. Add Error Context Stack
**Issue:** Hard to trace where errors occurred in nested function calls
**Fix:** Add context stack with push_context/pop_context functions

---

#### 25. Inconsistent Variable Naming Prefixes
**Issue:** Some functions use prefixes (ne_, ls_, cc_), others don't
**Fix:** Either use prefixes consistently OR use descriptive names without prefixes

---

#### 26. Inconsistent Quoting Style
**Issue:** Mix of single and double quotes where either would work
**Fix:** Document quoting rules and apply consistently

---

#### 27. Add set -euo pipefail Documentation
**Issue:** No guidance on whether scripts should use strict mode
**Fix:** Document recommendation and interaction with cleanup mechanism

---

#### 28. Missing Inline Comments for Complex Logic
**Issue:** Functions like `kids()` and `poll_reports()` lack explanatory comments
**Fix:** Add inline comments explaining non-obvious logic

---

#### 29. Add Examples to Function Documentation
**Issue:** Complex functions lack usage examples
**Fix:** Add example code blocks to function documentation

---

#### 30. Document Global Variable Requirements
**Issue:** No central documentation of what globals functions expect
**Fix:** Add section at top of bump.sh listing all global variables

---

#### 31. Optimize poll_reports Loop
**Issue:** Reads workers file and checks every PID on every iteration
**Fix:** Cache worker PIDs, only reread file periodically

---

#### 32. Add Integration Tests
**Issue:** No tests for complete workflows
**Fix:** Create test_integration.sh with realistic scenarios

---

#### 33. Improve Test Isolation
**Issue:** Tests override cleanup() which prevents testing real behavior
**Fix:** Use subprocesses or migrate to Bats for better isolation

---

### 🔵 LOW Priority (4+)

#### 34. Standardize Function Documentation Format
**Fix:** Apply consistent format to all function headers

---

#### 35. Add Troubleshooting Section to README
**Fix:** Document common error codes, debugging techniques, performance tips

---

#### 36. Consider Command Caching for check_dependency
**Fix:** Cache `command -v` results to avoid repeated PATH searches

---

#### 37. Various Documentation Improvements
- Examples in README
- Best practices guide
- Common patterns

---

## Test Coverage Status

| Priority        | Total Issues | Have Regression Tests | % Tested |
|-----------------|--------------|------------------------|----------|
| 🔴 Critical     | 4            | 3                      | 75%      |
| 🟡 High         | 12           | 4                      | 33%      |
| 🟢 Medium       | 13+          | 0                      | 0%       |
| 🔵 Low          | 4+           | 0                      | 0%       |
| **TOTAL**       | **33+**      | **7**                  | **21%**  |

---

## Recommended Implementation Order

### Phase 1: Critical Security (Week 1)
**Goal:** Eliminate security vulnerabilities

1. ✅ Fix regex injection in `check_contains` (HAS TEST)
2. ✅ Fix unsafe sed in `path_as_name` (HAS TEST)
3. ✅ Fix command injection in `apply_niceload` (HAS TEST)
4. ❌ Add file write validation (ADD TEST FIRST)

**Success Criteria:** All critical security tests pass

---

### Phase 2: High Priority Bugs (Week 2)
**Goal:** Fix tested bugs and add missing parallel functions

#### Part A: Tested Bugs (3-4 days)
1. ✅ Fix `log_message` parameter validation (HAS TEST)
2. ✅ Fix unvalidated `$ramdisk` (HAS TEST)
3. ✅ Fix fragile memory detection (HAS TEST)
4. ✅ Add cleanup recursion guard (HAS TEST)

#### Part B: Missing Parallel Functions (3-4 days)
5. ❌ Add 9 missing parallel functions (ADD TESTS AS YOU GO)
6. ❌ Fix cleanup array inconsistency

**Success Criteria:** All regression tests pass, parallel.sh has feature parity

---

### Phase 3: Code Quality (Week 3+)
**Goal:** Improve maintainability and documentation

1. Standardize error reporting
2. Add log levels
3. Split `report()` function
4. Add error context stack
5. Improve variable naming consistency
6. Add inline comments
7. Document global variables
8. Add integration tests
9. Improve test isolation (maybe migrate to Bats)
10. Documentation improvements

**Success Criteria:** Code is more maintainable, better documented

---

### Phase 4: Nice-to-Haves (Ongoing)
1. Performance optimizations
2. Additional edge case tests
3. Troubleshooting guide
4. Command caching
5. Code style consistency

---

## Quick Start: Fix the 7 Tested Bugs

If you want to start immediately, fix these in order:

1. **check_contains regex injection** (bump.sh:209) - Add `-F` flag
2. **log_message parameter** (bump.sh:109) - Fix variable name
3. **path_as_name sed** (bump.sh:254) - Use bash built-ins
4. **poll_reports ramdisk** (bump.sh:529) - Add validation
5. **free_memory_report columns** (bump.sh:477) - Robust parsing
6. **cleanup recursion** (bump.sh:344) - Add guard
7. **apply_niceload injection** (parallel.sh:230) - Quote and validate

After each fix, run:
```bash
./test_regression.sh  # Should have fewer failures
./run_all_tests.sh    # Ensure no regressions
```

---

## Files to Reference

- **CODE_REVIEW.md** - Detailed analysis of each issue with code examples
- **TEST_BASELINE.md** - Current test status and what passes/fails
- **TESTING_ANALYSIS.md** - Testing strategy and framework options
- **test_regression.sh** - Regression tests for bugs
- **run_all_tests.sh** - Run all test suites

---

## Summary

**Total Work:**
- 4 critical security fixes
- 12 high priority bugs
- 13+ medium priority improvements
- 4+ low priority enhancements

**Immediate Focus:**
- Fix 7 bugs with regression tests (1-2 weeks)
- Add 9 missing parallel functions (1 week)
- Everything else is code quality (ongoing)

**Current Test Coverage:** 7 of 33 issues have regression tests (21%)
