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

---

## Task 1.2: GNU Parallel Best Practices

### Real-World Example: Marathon Framework

**Location:** `/home/gusgw/src/cavewall/marathon/run.sh`

**Production Usage Pattern:**
```bash
# Main script sources both bump.sh and parallel.sh
. ${run_path}/bump/bump.sh
. ${run_path}/bump/parallel.sh

# Worker function (exported for GNU Parallel)
function run {
    local work="$1"
    local logs="$2"
    local ramdisk="$3"
    local job="$4"
    local input="$5"

    # PATTERN 1: Parallel functions log settings
    parallel_log_setting "workspace" "${work}"
    parallel_log_setting "job" "${job}"
    parallel_log_setting "file to work on" "${input}"

    # PATTERN 2: Parallel functions validate resources
    parallel_check_exists "${input}"
    mkdir -p "${work}" || parallel_report "$?" "make folder if necessary"
    parallel_check_exists "${work}"

    # PATTERN 3: Worker launches subprocess and monitors it
    some_long_running_command &
    mainid=$!

    # Worker uses load management in loop
    while kill -0 "${mainid}" 2> /dev/null; do
        sleep ${WAIT}
        apply_niceload "${mainid}" "${ramdisk}/workers" "${target_load}"
    done

    # PATTERN 4: Workers report errors but continue
    wait $mainid || parallel_report $? "waiting for run to finish"

    # PATTERN 5: Worker cleans up at end
    parallel_cleanup 0
    return 0
}
export -f run

# Main process launches parallel
find "${work}" -name "*.input" |\
    parallel --results "${logs}/run/{/}/" \
             --joblog "${logs}/${STAMP}.${job}.run.log" \
             --jobs "${MAX_SUBPROCESSES}" \
        run "${work}" "${logs}" "${ramdisk}" "${job}" {} &
parallel_pid=$!

# PATTERN 6: Main process monitors resources (NOT workers)
poll_reports "$parallel_pid" "$$" "${WAIT}" &
report_pid=$!

# Main process waits for completion
while kill -0 "$parallel_pid" 2> /dev/null; do
    sleep ${WAIT}
done

# Main process cleans up
cleanup 0
```

### Key Patterns Observed

**1. Division of Responsibilities:**
- **Main Process:** Monitoring, resource management, cleanup
- **Workers:** Validation, logging, processing, error reporting

**2. Functions Used by Workers:**
- ✓ `parallel_log_setting` - Extensive logging of configuration
- ✓ `parallel_check_exists` - File/directory validation
- ✓ `parallel_report` - Error reporting without exiting
- ✓ `parallel_cleanup` - Cleanup at worker completion
- ✓ `apply_niceload` - Load management for worker subprocesses

**3. Functions Used by Main Process:**
- ✓ `poll_reports` - Monitor parallel_pid resource usage
- ✓ `cleanup` - Final cleanup after all workers complete

**4. Functions NOT Used:**
- ✗ `parallel_check_md5` - Not needed in this workflow
- ✗ `parallel_check_contains` - Not needed in this workflow
- ✗ `parallel_memory_report` - Monitoring done by main process
- ✗ `parallel_load_report` - Monitoring done by main process
- ✗ `parallel_free_memory_report` - Monitoring done by main process

### GNU Parallel Best Practices (from documentation)

**1. Function Export:**
```bash
function my_func() { echo "in my_func $1"; }
export -f my_func
parallel my_func ::: 1 2 3
```

**2. Resource Control:**
- Use `--jobs N` to control parallelism
- Use `--load 75%` to monitor system load
- Use `--halt soon,fail=10%` for early failure detection

**3. Job Design:**
- Workers should be self-contained
- Workers should validate their own inputs
- Workers should log their own progress
- Workers should return error codes, not exit

**4. Monitoring:**
- Main process monitors overall resources
- Main process tracks parallel job PID
- Workers focus on their specific task

### Conclusions from Real-World Usage

**Validated Needs:**
1. ✅ Logging functions - Extensively used by workers
2. ✅ Validation functions - Workers validate their inputs
3. ✅ Error reporting - Workers report but don't exit
4. ✅ Load management - Workers manage subprocess load
5. ✅ Basic cleanup - Workers clean up their resources

**Not Needed:**
1. ❌ Monitoring in workers - Main process handles monitoring
2. ❌ Complex validation - Not used in practice
3. ❌ Dependency checking - Done once at script start

---

## Task 1.3: Realistic Usage Scenarios

### Scenario 1: Data Pipeline (Real - from Marathon)

**Use Case:** Process input files in parallel, each worker validates and transforms data

**Functions Needed:**
- `parallel_log_setting` - Log which file worker is processing
- `parallel_check_exists` - Validate input file exists
- `parallel_report` - Report errors without killing other workers
- `parallel_cleanup` - Clean up worker temp files

**NOT Needed:**
- `parallel_check_md5` - Checksums validated before parallel processing
- `parallel_memory_report` - Main process monitors all workers

### Scenario 2: Batch Image Processing (Hypothetical)

**Use Case:** Convert images in parallel, validate output quality

**Potential Functions:**
- `parallel_check_md5` - Verify input images not corrupted
- `parallel_check_exists` - Validate output directory
- `parallel_log_setting` - Log processing parameters

**Analysis:**
- `check_md5` could be useful here BUT:
  - Checksum validation is CPU-intensive
  - Better done before/after parallel processing
  - Main process can validate checksums more efficiently

**Alternative:** Validate checksums in main process before starting workers

### Scenario 3: Log Analysis (Hypothetical)

**Use Case:** Search log files for patterns in parallel

**Potential Functions:**
- `parallel_check_contains` - Search for patterns in each file
- `parallel_check_exists` - Validate log file exists

**Analysis:**
- `check_contains` searches files for content
- But check_contains uses `grep` which already works in parallel
- No need for parallel wrapper

**Alternative:** Use `parallel grep "pattern" ::: *.log` directly

### Scenario 4: System Administration (Hypothetical)

**Use Case:** Check dependencies on multiple systems

**Potential Functions:**
- `parallel_check_dependency` - Verify commands exist

**Analysis:**
- Dependency checking is a one-time operation at script start
- No need to check repeatedly in each worker
- Main script should validate dependencies before launching workers

**Alternative:** Use regular `check_dependency` in main process

### Decision Matrix

| Function | Real Usage | Hypothetical Usage | Decision |
|----------|-----------|-------------------|----------|
| `parallel_check_md5` | None | Possible but inefficient | ❌ NOT NEEDED |
| `parallel_check_contains` | None | Redundant with grep | ❌ NOT NEEDED |
| `parallel_check_dependency` | None | Wrong pattern | ❌ NOT NEEDED |
| `parallel_path_as_name` | None | No side effects | ❌ NOT NEEDED* |
| `parallel_load_report` | None | Wrong pattern | ❌ NOT NEEDED |
| `parallel_memory_report` | None | Wrong pattern | ❌ NOT NEEDED |
| `parallel_free_memory_report` | None | Wrong pattern | ❌ NOT NEEDED |
| `parallel_slow` | None | Anti-pattern | ❌ NOT NEEDED |

\* `path_as_name` is a pure utility function with no side effects, exits, or cleanup. Regular version works fine in parallel contexts.

---

## Task 1.4: Evaluate parallel_cleanup Array vs String

### Current Implementation

**Code (parallel.sh line 118):**
```bash
parallel_cleanup_function=""  # Single string variable
```

**Usage:**
```bash
parallel_cleanup_function="parallel_cleanup_test"

function parallel_cleanup {
    if [[ -n "$parallel_cleanup_function" ]]; then
        if [[ "$parallel_cleanup_function" == parallel_cleanup_* ]]; then
            if declare -f "$parallel_cleanup_function" >/dev/null 2>&1; then
                "$parallel_cleanup_function" "${rc}" || true
            fi
        fi
    fi
}
```

### Real-World Usage (Marathon run.sh)

**Pattern:**
```bash
function run {
    # ... worker logic ...

    # Single cleanup at end
    parallel_cleanup 0
    return 0
}
```

**Observation:** Marathon uses `parallel_cleanup` but does NOT register any custom cleanup function

### Analysis: Do Parallel Workers Need Multiple Cleanup Functions?

**Arguments for Array (Multiple Functions):**
1. Consistency with main cleanup (uses array)
2. Complex workers might need multiple cleanup steps
3. Libraries could register cleanup functions

**Arguments Against Array (Single Function):**
1. No real-world usage of even ONE custom cleanup function
2. Workers are typically simple and self-contained
3. Worker lifecycle is short - easier to cleanup manually
4. Adding complexity for unused feature
5. Main process handles complex cleanup, not workers

### Real-World Comparison

**Main Process Cleanup:**
- Long-running script
- Multiple resource acquisitions
- Complex state management
- Needs multiple cleanup functions

**Worker Process Cleanup:**
- Short-lived (processes one item)
- Simple resource usage
- Limited state
- Single cleanup (if any) is sufficient

### Decision: Keep Single String

**Rationale:**
1. Zero usage of custom cleanup functions in production
2. Workers are too simple to need multiple cleanup functions
3. Simpler implementation is better when unused
4. Can always change to array later if real need emerges
5. Main process already handles complex cleanup

**Recommendation:** Document that workers should be simple and self-contained. Complex cleanup belongs in main process.

---

## Task 1.5: Final Decisions

### Functions Implemented and Validated ✅

**Keep these - used in production:**

1. **parallel_not_empty** ✅
   - **Status:** Implemented and tested
   - **Usage:** Input validation in workers
   - **Keep:** YES - fundamental validation

2. **parallel_log_setting** ✅
   - **Status:** Implemented and tested
   - **Usage:** Extensive use in Marathon workers
   - **Keep:** YES - critical for debugging parallel jobs

3. **parallel_log_message** ✅
   - **Status:** Implemented and tested
   - **Usage:** General message logging in workers
   - **Keep:** YES - useful for worker progress tracking

4. **parallel_report** ✅
   - **Status:** Implemented and tested
   - **Usage:** Error reporting without exit in Marathon
   - **Keep:** YES - essential for parallel error handling

5. **parallel_check_exists** ✅
   - **Status:** Implemented and tested
   - **Usage:** Input validation in Marathon workers
   - **Keep:** YES - validates worker inputs

6. **parallel_cleanup** ✅
   - **Status:** Implemented and tested
   - **Usage:** Called in Marathon workers (no custom function though)
   - **Keep:** YES - standard worker completion
   - **Note:** Keep as single string variable (not array)

7. **kids** ✅
   - **Status:** Implemented and tested
   - **Usage:** Process tree traversal for apply_niceload
   - **Keep:** YES - required for load management

8. **apply_niceload** ✅
   - **Status:** Implemented and tested
   - **Usage:** Load management in Marathon workers
   - **Keep:** YES - critical for system resource management

### Functions NOT Needed ❌

**Do not implement - no valid use case:**

1. **parallel_check_md5** ❌
   - **Rationale:** Checksum validation is expensive, should be done in main process before/after parallel execution
   - **Alternative:** Use regular `check_md5` in main process
   - **Remove from bug list:** YES

2. **parallel_check_contains** ❌
   - **Rationale:** Content searching already works with parallel + grep
   - **Alternative:** `parallel grep "pattern" ::: files` or use regular `check_contains`
   - **Remove from bug list:** YES

3. **parallel_check_dependency** ❌
   - **Rationale:** Dependencies checked once at script start, not per-worker
   - **Alternative:** Use regular `check_dependency` in main process before launching parallel
   - **Remove from bug list:** YES

4. **parallel_path_as_name** ❌
   - **Rationale:** Pure utility function with no side effects, exits, or state. Regular version works fine in parallel.
   - **Alternative:** Use regular `path_as_name` - it's already safe
   - **Remove from bug list:** YES

5. **parallel_slow** ❌
   - **Rationale:** Anti-pattern - workers shouldn't wait for external processes. Main process handles synchronization.
   - **Alternative:** Use regular `slow` in main process
   - **Remove from bug list:** YES

6. **parallel_load_report** ❌
   - **Rationale:** Monitoring done by main process using `poll_reports`, not by individual workers
   - **Alternative:** Main process monitors with `poll_reports`
   - **Remove from bug list:** YES

7. **parallel_memory_report** ❌
   - **Rationale:** Main process monitors all workers collectively
   - **Alternative:** Main process uses `poll_reports` which calls `memory_report`
   - **Remove from bug list:** YES

8. **parallel_free_memory_report** ❌
   - **Rationale:** System-wide monitoring belongs in main process
   - **Alternative:** Main process uses `poll_reports` which calls `free_memory_report`
   - **Remove from bug list:** YES

### Summary

**Result:** All 8 currently implemented functions are validated and should be kept.

**Result:** All 9 "missing" functions are NOT needed and should NOT be implemented.

**Impact on Bug List:**
- Remove 9 items from "missing parallel functions" section
- Document design pattern: workers validate and process, main process monitors

### Design Pattern Documentation

**Parallel Job Design Pattern:**

```
Main Process:
├── Validate dependencies (check_dependency)
├── Validate inputs (check_md5, check_contains)
├── Launch parallel workers
├── Monitor resources (poll_reports)
│   ├── load_report
│   ├── memory_report
│   └── free_memory_report
├── Wait for completion
└── Cleanup (cleanup)

Worker Process (per input):
├── Validate input exists (parallel_check_exists)
├── Log configuration (parallel_log_setting)
├── Process input
│   ├── Launch subprocess if needed
│   └── Manage subprocess load (apply_niceload)
├── Report errors if any (parallel_report)
└── Cleanup worker resources (parallel_cleanup)
```

**Key Principles:**
1. **Validate once:** Main process validates dependencies and shared resources
2. **Monitor centrally:** Main process monitors all workers collectively
3. **Workers are simple:** Workers validate their specific input and process it
4. **Errors don't stop others:** Workers report errors but don't exit entire process
5. **Cleanup is minimal:** Workers cleanup their specific resources, main handles complex cleanup

---

## Appendix: Marathon Framework Analysis

**Script:** `/home/gusgw/src/cavewall/marathon/run.sh`

**Purpose:** Parallel computation framework for embarrassingly parallel jobs using GNU Parallel

**Key Features:**
- Coordinates data fetching with rclone
- Manages parallel job execution with load balancing
- Handles AWS Spot instance interruptions
- Provides continuous output synchronization

**Parallel Usage:**
- Sources both `bump.sh` and `parallel.sh`
- Exports worker function `run()`
- Uses GNU Parallel with `--results` and `--joblog`
- Main process monitors with `poll_reports`
- Workers use `apply_niceload` for subprocess management

**Functions Used:**
- parallel_log_setting (lines 200-207)
- parallel_check_exists (lines 209, 221)
- parallel_report (lines 220, 257, 261)
- parallel_cleanup (line 275)
- apply_niceload (lines 239, 248)
- poll_reports (line 301 - in main process)
- cleanup (line 322 - in main process)

This production usage perfectly demonstrates the intended design pattern.
