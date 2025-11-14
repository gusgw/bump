# Parallel Functions Usage Analysis

**Date:** 2025-11-14
**Task:** Phase 1.1 - Search codebase for actual parallel.sh usage

---

## Executive Summary

**Key Finding:** parallel.sh has **NO actual production usage** in the codebase.

**Evidence:**
- Only used in test files (test_parallel.sh, test_regression.sh)
- No production scripts source parallel.sh
- README.md contains idealized examples but no real implementations
- Main production script (cas/21cm/script/cpu.sh) uses bump.sh but not parallel.sh

---

## Detailed Findings

### 1. Usage in BUMP Repository

**Files that reference parallel.sh:**
- `test_parallel.sh` - Unit tests for parallel functions (50 assertions)
- `test_regression.sh` - Sources parallel.sh to test BUG: unquoted variable expansion
- `run_all_tests.sh` - Runs test_parallel.sh as part of test suite
- `parallel.sh` - The library itself

**Result:** Only test usage, no production usage in BUMP repository

### 2. Usage in Sibling Repositories

**Searched directories:**
- `../cas/21cm/` - CAS 21cm simulations project
- `../task/` - Task management scripts
- `../daily/` - Daily automation scripts

**Found:**
- Copy of BUMP library at `../cas/21cm/lib/bump/` (includes parallel.sh)
- README.md documentation mentions parallel.sh
- Production script `cpu.sh` sources bump.sh but NOT parallel.sh

**Result:** No production usage found in any sibling repository

### 3. Current parallel.sh Implementation

**Implemented Functions (8 total):**
1. `parallel_not_empty` - Parameter validation
2. `parallel_log_setting` - Setting logging with parallel job info
3. `parallel_log_message` - Message logging with parallel job info
4. `parallel_report` - Error reporting without exit
5. `parallel_check_exists` - File/directory existence check
6. `parallel_cleanup` - Cleanup handler (uses single string variable)
7. `kids` - Find all child processes recursively
8. `apply_niceload` - Apply load limiting to process trees

**Key Characteristics:**
- All functions return error codes instead of calling cleanup
- All functions include GNU Parallel environment variables in output:
  - `PARALLEL_PID` - Process ID
  - `PARALLEL_JOBSLOT` - Job slot number (1 to N)
  - `PARALLEL_SEQ` - Job sequence number
- All functions are exported with `export -f`

### 4. Cleanup Implementation Analysis

**Current:**
```bash
parallel_cleanup_function=""  # Single string variable
```

**Usage in parallel_cleanup():**
- Checks if `parallel_cleanup_function` is non-empty
- Validates function name starts with `parallel_cleanup_`
- Calls the function if it exists

**Observation:** Only supports ONE cleanup function per parallel job

### 5. bump.sh Functions (for comparison)

**Total functions in bump.sh:** 17

**Functions WITHOUT parallel versions:**
1. `log_message` - WAIT, parallel_log_message EXISTS (line 60-76)
2. `check_md5` - Checksum verification
3. `check_contains` - File content search
4. `check_dependency` - Command availability check
5. `path_as_name` - Path-to-name conversion
6. `slow` - Wait for processes to terminate
7. `load_report` - System load logging
8. `memory_report` - Process memory logging
9. `free_memory_report` - Free memory logging
10. `poll_reports` - Continuous monitoring loop

**Functions WITH parallel versions:**
1. `not_empty` → `parallel_not_empty` ✓
2. `log_setting` → `parallel_log_setting` ✓
3. `check_exists` → `parallel_check_exists` ✓
4. `report` → `parallel_report` ✓
5. `cleanup` → `parallel_cleanup` ✓

---

## README.md Example Analysis

### Example 3: Parallel Data Processing (from README)

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

**Functions Used in Example:**
- `parallel_check_exists` ✓ (implemented)
- `parallel_log_setting` ✓ (implemented)
- `parallel_report` ✓ (implemented)

**Functions NOT Used:**
- `parallel_check_md5` - Would be useful for validating data files
- `parallel_check_contains` - Would be useful for data validation
- `parallel_check_dependency` - Already handled at script level
- `parallel_load_report` - Not used in example
- `parallel_memory_report` - Not used in example
- `parallel_free_memory_report` - Not used in example
- `parallel_slow` - Not applicable in parallel context
- `parallel_cleanup` - Not explicitly called (implicit)

---

## GNU Parallel Documentation References

According to the README:
> BUMP integrates with [GNU Parallel](https://www.gnu.org/software/parallel/), for concurrent execution while maintaining consistent error handling and resource tracking across parallel jobs.

**Best Practices from README:**
1. Export functions with `export -f function_name`
2. Export required variables (like `STAMP`)
3. Use `--halt soon,fail=N%` for early failure detection
4. Parallel functions should return error codes, not exit

---

## Conclusions from Task 1.1

### Usage Patterns
1. **Zero production usage** - parallel.sh has never been used in production
2. **Test coverage only** - All usage is in test files
3. **Documentation exists** - README.md has examples of intended usage
4. **No real-world validation** - Examples are theoretical, not battle-tested

### Implementation Status
1. **Core functions implemented** - Basic validation, logging, reporting work
2. **Advanced functions missing** - No parallel versions of monitoring functions
3. **Validation functions incomplete** - Missing check_md5, check_contains, check_dependency
4. **Single cleanup function** - Limited to one cleanup per job (string not array)

### Critical Questions for Next Tasks
1. **Are monitoring functions (load_report, memory_report) needed in parallel jobs?**
   - Monitoring in parallel contexts is complex
   - Main process usually handles monitoring
   - Workers typically just process and report errors

2. **Are validation functions (check_md5, check_contains) needed?**
   - Useful for data pipeline scenarios
   - Example shows need for file validation
   - Should be relatively easy to implement

3. **Is check_dependency needed in parallel version?**
   - Dependency checking typically done once at script start
   - Unlikely to need parallel version

4. **Should path_as_name have parallel version?**
   - Utility function with no side effects
   - Regular version should work fine in parallel
   - No cleanup or exit calls

5. **Is parallel_slow needed?**
   - slow() waits for processes to terminate
   - Parallel jobs shouldn't wait for other processes
   - Main script handles process synchronization

6. **Should parallel_cleanup_function be an array?**
   - Current: Single string variable
   - Regular cleanup uses array for multiple functions
   - Need to determine if parallel jobs need multiple cleanup functions

---

## Next Steps (Tasks 1.2-1.5)

**Task 1.2:** Analyze GNU Parallel best practices
- Research parallel job patterns
- Understand typical use cases
- Determine if monitoring/validation functions are used in parallel contexts

**Task 1.3:** Create realistic usage scenarios
- Design concrete examples for each missing function
- Determine if each function is actually needed
- Show code examples demonstrating need OR alternative approaches

**Task 1.4:** Evaluate parallel_cleanup array vs string
- Determine if multiple cleanup functions are needed in parallel jobs
- Show example requiring multiple cleanups OR justify single cleanup

**Task 1.5:** Make final decisions
- Decide which functions to implement
- Decide which functions are not needed
- Update PLAN.md bug list accordingly
