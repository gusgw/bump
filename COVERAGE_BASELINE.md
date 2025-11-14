# Test Coverage Baseline

**Date:** 2025-11-14
**Bashcov Version:** 3.2.0
**Ruby Version:** 3.4.7
**Bash Version:** 5.3

## Summary

**Overall Line Coverage:** 32.0% (455 / 1,422 lines)

**Test Files Run:**
- test_bump.sh (13 test cases, 45 assertions)
- test_bump_advanced.sh (6 test cases, 17 assertions passing, 1 failing*)

\* One test failure in slow() function test - timing issue, not a code bug

**Coverage Report:** `baseline_coverage.html` (720KB)

## Coverage by Source File

### bump.sh
- **Primary functions library**
- Contains: error handling, validation, monitoring, cleanup functions
- Lines: ~546 total
- Coverage: Partial - core functions covered, some monitoring functions partially covered

**Covered Functions:**
- set_stamp() - timestamp generation ✓
- set_month() - month string generation ✓
- not_empty() - parameter validation ✓
- log_setting() - setting logging ✓
- check_exists() - file existence validation ✓
- check_dependency() - command availability check ✓
- check_contains() - file content validation ✓
- check_md5() - checksum verification ✓
- report() - error reporting ✓
- path_as_name() - path conversion ✓
- print_rule() / print_error_rule() - separators ✓
- handle_signal() - signal handler ✓
- cleanup() - cleanup orchestration ✓
- slow() - process waiting ✓
- load_report() - system load logging ✓
- memory_report() - process memory logging ✓
- free_memory_report() - free memory logging ✓

**Partially Covered / Uncovered:**
- poll_reports() - complex monitoring loop (partial coverage)
- Various error paths and edge cases
- Some validation branches

### parallel.sh
- **Parallel-safe function implementations**
- Lines: ~246 total
- Coverage: UNKNOWN (not tested in baseline - no parallel tests run)

**Expected Uncovered Functions:**
- parallel_not_empty()
- parallel_log_setting()
- parallel_log_message()
- parallel_report()
- parallel_check_exists()
- parallel_cleanup()
- kids() - process tree traversal
- apply_niceload() - load limiting

**Note:** test_parallel.sh was not run in baseline due to performance issues with bashcov.

### return_codes.sh
- **Exit code constants**
- Lines: ~42 total
- Coverage: Should be 100% (all constants are referenced)

**Constants Defined:**
- MISSING_INPUT, MISSING_FILE, MISSING_FOLDER, MISSING_DISK, MISSING_MOUNT, MISSING_CMD
- BAD_CONFIGURATION, UNSAFE, CORRUPT_DATA
- SYSTEM_UNIT_FAILURE, SECURITY_FAILURE, NETWORK_ERROR, FILING_ERROR
- TRAPPED_SIGNAL, SHUTDOWN_SIGNAL

## Known Issues with Baseline Measurement

### 1. Performance Issues
Bashcov adds significant overhead:
- test_bump.sh alone: normal ~2s, with bashcov ~30s (15x slowdown)
- test_bump_advanced.sh: normal ~5s, with bashcov ~97s (19x slowdown)
- Full test suite: abandoned after 5+ minutes

**Impact:** Unable to measure coverage from all test files in reasonable time.

### 2. Missing test files
**Not included in baseline:**
- test_parallel.sh (51 assertions for parallel functions)
- test_coverage.sh (55 assertions for edge cases)
- test_regression.sh (10 assertions for known bugs)

**Estimated Impact:** These tests would likely add 10-15% more coverage, bringing total to ~45-47%.

### 3. Test Failures
The slow() function test failed due to timing (took 97s instead of expected 2-3s). This is a bashcov performance issue, not a code bug.

## Gap Analysis

### High Priority Uncovered Code

1. **parallel.sh Functions (0% coverage)**
   - All 8 parallel functions uncovered
   - kids() function uncovered
   - apply_niceload() uncovered

2. **Error Paths**
   - File write failures (permissions, disk full)
   - Missing command scenarios
   - Invalid input validation branches

3. **Edge Cases**
   - Very long paths
   - Special characters in inputs
   - Race conditions
   - Signal handling during operations

4. **poll_reports() Function**
   - Complex loop with multiple branches
   - Worker file reading
   - Process monitoring
   - Partial coverage only

### Medium Priority Uncovered Code

1. **Defensive Code**
   - Cleanup function error handling
   - Report function edge cases
   - Memory detection fallbacks

2. **Platform-Specific Code**
   - /proc filesystem checks
   - Command availability checks
   - Different free command versions

### Low Priority Uncovered Code

1. **Error Messages**
   - Various echo statements
   - Different error message variations

2. **Initialization**
   - Global variable defaults
   - Configuration loading

## Target Coverage

**Goal:** 90%+ line coverage

**Path to 90%:**
1. Fix bashcov performance or find alternative measurement approach
2. Run all test files (adds ~15% coverage)
3. Add tests for parallel functions (adds ~10% coverage)
4. Add edge case tests (adds ~10% coverage)
5. Add error path tests (adds ~10-15% coverage)

**Realistic Estimate:** With all tests and improvements, we can reach 85-95% coverage.

**Acceptable Gaps:**
- Unreachable defensive code
- Platform-specific fallbacks
- Error message variations

## Next Steps (PLAN.md Phase 0)

- [ ] 0.3: Fix test environment issues (cleanup callbacks, slow test)
- [ ] 0.4: Add tests for uncovered functions
- [ ] 0.5: Add edge case and error path tests
- [ ] 0.6: Document final coverage results

## Notes

### hostname Command Missing
The test environment doesn't have the `hostname` command, causing warnings. Tests work around this. In production environments, hostname should be available.

### Bashcov Performance
Consider alternatives:
- kcov (C/C++ coverage tool, supports bash)
- shcov (pure bash coverage, may be faster)
- Manual line counting with tracing enabled
- Split tests into smaller chunks

### Coverage Report Access
HTML report saved as: `baseline_coverage.html` (720KB)
- Open in browser to view line-by-line coverage
- Shows covered/uncovered lines color-coded
- File-by-file breakdown with statistics

## Baseline Conclusion

**Current State:** 32% coverage with core tests only

**With All Tests:** Estimated 45-47% coverage

**Target:** 90%+ coverage

**Gap to Close:** ~45-50 percentage points

**Feasibility:** Achievable with planned test additions in Phase 0 tasks 0.4 and 0.5.
