# Manual Review Items

**Created:** 2025-11-14
**Purpose:** Document issues requiring manual review during Phase 4

---

## Overview

This document lists issues identified in the code review that cannot be tested via automated regression tests. These are primarily:
- Code style and consistency issues
- Documentation improvements
- Design/architectural considerations
- Items already addressed

All items in this list will be reviewed and addressed during Phase 4: Final Code Review.

---

## Medium Priority Issues

### M1. Inconsistent Error Reporting
- **Severity:** Medium
- **Issue:** Mix of `echo >&2`, `report()`, `log_message()` for error reporting
- **Impact:** Harder to parse logs systematically
- **Files:** bump.sh, parallel.sh
- **Manual Review:** Check all error reporting calls and standardize on one approach
- **Recommendation:** Use `report()` for errors that should be logged, `echo >&2` for debug output

### M2. No Log Levels
- **Severity:** Medium
- **Issue:** No way to filter logs by severity (DEBUG, INFO, WARN, ERROR)
- **Impact:** Can't control log verbosity
- **Manual Review:** Decide if log levels should be added as a feature
- **Recommendation:** This is a design decision - consider adding DEBUG/INFO/WARN/ERROR levels to log_message()

### M3. Confusing report() Dual Behavior
- **Severity:** Medium
- **Issue:** `report()` continues execution OR exits based on third parameter
- **Impact:** Confusing API - not obvious from function name
- **Manual Review:** Consider renaming or splitting into two functions
- **Recommendation:** Could split into `report()` (continues) and `fatal()` (exits)

### M4. No Error Context Stack
- **Severity:** Medium
- **Issue:** Hard to trace nested errors - no call stack or context breadcrumbs
- **Impact:** Debugging nested function calls is harder
- **Manual Review:** Evaluate if error context tracking would be valuable
- **Recommendation:** Could add BASH_SOURCE and BASH_LINENO to error messages

### M5. Inconsistent Variable Naming
- **Severity:** Medium
- **Issue:** Some functions use prefixes (lm_message, ce_file_name), others don't
- **Impact:** Code is less readable, inconsistent patterns
- **Files:** bump.sh, parallel.sh
- **Manual Review:** Audit all function variables for consistency
- **Recommendation:** All functions should use prefixed local variables

### M6. Inconsistent Quoting Style
- **Severity:** Medium
- **Issue:** Mix of single quotes and double quotes
- **Impact:** Minor style inconsistency
- **Manual Review:** Not critical, but could standardize during refactoring
- **Recommendation:** Use double quotes for variable expansion, single for literals

### M7. No set -euo pipefail Guidance
- **Severity:** Medium
- **Issue:** No documentation on whether scripts using bump.sh should use strict mode
- **Impact:** Users unsure whether to use `set -euo pipefail`
- **Manual Review:** Document compatibility with strict mode
- **Recommendation:** Test bump.sh with strict mode and document results in README

### M8. Missing Inline Comments
- **Severity:** Medium
- **Issue:** Complex functions (poll_reports, kids) lack inline comments
- **Impact:** Code harder to understand
- **Files:** bump.sh:514-567 (poll_reports), parallel.sh:160-189 (kids)
- **Manual Review:** Add inline comments to complex logic sections
- **Recommendation:** Focus on poll_reports loop and kids recursion

### M9. Missing Function Examples
- **Severity:** Medium
- **Issue:** Complex functions lack usage examples in documentation
- **Impact:** Harder to learn API, especially poll_reports, kids, apply_niceload
- **Manual Review:** Add usage examples to function documentation
- **Recommendation:** See PARALLEL_USAGE.md for good examples to adapt

### M10. Undocumented Global Variables
- **Severity:** Medium
- **Issue:** No central list of global variables (STAMP, RULE, WAIT, cleanup_functions)
- **Impact:** Users don't know what variables to set or what they do
- **Manual Review:** Document all globals in README or bump.sh header
- **Recommendation:** Add "Global Variables" section to README

### M11. Unoptimized poll_reports Loop
- **Severity:** Medium
- **Issue:** Rereads $ramdisk/workers file every iteration
- **Impact:** Potential performance issue with many workers
- **Files:** bump.sh:545-554
- **Manual Review:** Evaluate if optimization is needed
- **Recommendation:** Could cache workers list and only re-read on change
- **Note:** Not critical unless profiling shows it's a bottleneck

### M12. No Integration Tests
- **Severity:** Medium
- **Issue:** No end-to-end workflow tests
- **Impact:** May miss integration bugs
- **Manual Review:** Decide if integration tests should be added
- **Recommendation:** Current unit tests cover most scenarios well
- **Note:** This is not a bug, but a potential improvement for Phase 5

### M13. Poor Test Isolation
- **Severity:** Medium
- **Status:** ✅ FIXED in Phase 0, Task 0.3
- **Issue:** Tests override cleanup, breaking callback tests
- **Resolution:** Fixed by using subprocesses for cleanup tests
- **Manual Review:** Verify fix is working (already verified)

---

## Low Priority Issues

### L1. Inconsistent Function Documentation Format
- **Severity:** Low
- **Issue:** Documentation format varies between functions
- **Impact:** Slightly harder to read
- **Manual Review:** Standardize documentation format across all functions
- **Recommendation:** Use consistent format:
  ```bash
  # function_name: Brief description
  #
  # Detailed description with behavior notes.
  # Multiple paragraphs if needed.
  #
  # Usage: function_name "arg1" "arg2"
  # Args:
  #   $1 - Description of arg1
  #   $2 - Description of arg2
  # Returns: Exit codes or return values
  # Globals: Any global variables used/modified
  ```

### L2. Missing Troubleshooting Section
- **Severity:** Low
- **Issue:** No troubleshooting guide in README
- **Impact:** Users may struggle with common issues
- **Manual Review:** Add troubleshooting section to README
- **Recommendation:** Cover common issues:
  - "cleanup called with exit code: 60" → check function parameters
  - Missing dependencies → install required commands
  - Permission errors → check file/directory permissions
  - /proc not available → system limitations

### L3. No CHANGELOG
- **Severity:** Low
- **Issue:** No CHANGELOG.md tracking changes
- **Impact:** Users don't know what changed between versions
- **Manual Review:** Create CHANGELOG.md
- **Recommendation:** Start with this PR as version 2.0.0

### L4. No VERSION File
- **Severity:** Low
- **Issue:** No version number in code
- **Impact:** Can't determine which version is installed
- **Manual Review:** Add VERSION file or version variable
- **Recommendation:** Add VERSION="2.0.0" to bump.sh

---

## Summary Statistics

**Total Issues Identified:** 33+
- **Critical (tested):** 4 - All have regression tests ✅
- **High (tested):** 6 - All have regression tests ✅
- **High (not bugs):** 10 - Resolved in Phase 1 as correct by design ✅
- **Medium (manual review):** 13 - Documented in this file (1 already fixed)
- **Low (manual review):** 4 - Documented in this file

**Test Coverage:**
- Regression tests: 12 test cases, 20+ assertions
- All behavioral bugs have automated tests
- All non-behavioral issues documented for manual review

**Next Steps:**
- Phase 3: Fix bugs using TDD based on regression tests
- Phase 4: Address manual review items from this document
