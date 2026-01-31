# BUMP Improvement Progress

This file tracks progress through the phases defined in PLAN.md,
with enough detail to repeat the work.

---

## Phase 3A: Fix Critical Security Issues

**Status:** Complete (fixes applied in prior branch, merged to develop)

**Date confirmed:** 2026-01-31

### What was done

Four critical security bugs were fixed:

1. **3A.1 — Regex injection in check_contains (bump.sh)**
   - `grep` call changed to `grep -qsF` to treat search strings as literals
   - Prevents attacker-controlled strings from being interpreted as regex
   - Location: bump.sh, `check_contains` function (line ~246)

2. **3A.2 — Unsafe sed in path_as_name (bump.sh)**
   - Replaced `sed` with bash built-in string manipulation:
     ```bash
     pan_result="${pan_result#/}"              # Remove leading slash
     pan_result="${pan_result//\//-}"           # Replace / with -
     pan_result="${pan_result//[[:space:]]/_}"  # Replace spaces with _
     ```
   - Eliminates sed delimiter injection with special characters
   - Location: bump.sh, `path_as_name` function (lines ~296-299)

3. **3A.3 — Command injection in apply_niceload (parallel.sh)**
   - Added whitelist regex validation for `OPT_NICELOAD`:
     ```bash
     if ! [[ "${OPT_NICELOAD}" =~ ^[a-zA-Z0-9_=\ -]+$ ]]; then
         # reject unsafe characters
     fi
     ```
   - Location: parallel.sh, `apply_niceload` function (lines ~242-249)

4. **3A.4 — Unvalidated file writes in report functions (bump.sh)**
   - Added directory existence and writability checks before file writes
   - Returns `FILING_ERROR` if directory missing, `SECURITY_FAILURE` if not writable
   - Applied to: `load_report` (~472-478), `memory_report` (~520-526), `free_memory_report` (~578-584)

### Test results

- All 13 regression tests pass (BUGs 1-13)
- test_bump.sh: 13 cases, 44/44 assertions pass
- test_bump_advanced.sh: 6 cases, 18/18 assertions pass

### Key commits (from prior branch, now merged)

- `304204c` Fix command injection vulnerability in apply_niceload (C1)
- `c23999a` Add file write validation to report functions (C4)
- `d68bf8c` Fix critical bugs, harden security, and refactor codebase

---

## Phase 3B: Fix High Priority Bugs

**Status:** Complete (fixes applied in prior branch, merged to develop)

**Date confirmed:** 2026-01-31

### What was done

Six high priority bugs were fixed, four were resolved as not-bugs:

1. **3B.2 — log_message parameter validation (bump.sh:132-137)**
   - Changed second `not_empty` call from `"date stamp"` to `"message"`
   - Now correctly validates both the message parameter and STAMP

2. **3B.3 — Unvalidated $ramdisk in poll_reports (bump.sh:653)**
   - Added `not_empty "ramdisk directory" "${ramdisk}"` at function entry

3. **3B.4 — Fragile memory detection in free_memory_report (bump.sh:601-602)**
   - Uses awk ternary: `($7 != "") ? $7 : ($4 + $6)` to handle varying `free` output formats

4. **3B.5 — Cleanup recursion guard (bump.sh:413-417)**
   - Added `CLEANUP_RUNNING` environment variable guard at start of cleanup()

5. **3B.6 — check_md5 return code handling (bump.sh:200-204)**
   - Added explicit `[[ ! -e "$cm_file" ]]` check with proper error return before MD5 computation

6. **3B.7 — PID validation in kids (parallel.sh:179-185)**
   - Moved `parallel_not_empty` and numeric regex check before any use of the PID value

7. **3B.8/3B.9 — Missing parallel functions / cleanup array**
   - Resolved in Phase 1: not needed. No code changes required.

### Test results

- All 13 regression tests pass
- test_bump.sh: 44/44, test_bump_advanced.sh: 18/18

### Key commits (from prior branch, now merged)

- `26b41bc` Fix wrong parameter validation in log_message (H1)
- `bd05b6c` Fix all High Priority bugs (H1, H2, H5, H6)

---

## Phase 3C: Fix Medium and Low Priority Issues

**Status:** Complete (addressed in prior branch, merged to develop)

**Date confirmed:** 2026-01-31

### What was done

- Phase 2 analysis determined all Medium priority issues were code style,
  documentation, or design issues with no testable behavioral bugs
- 13 Medium and 4 Low priority issues documented in MANUAL_REVIEW_ITEMS.md
- Error reporting consistency improved in prior branch work
- Variable naming follows existing prefix conventions throughout
- All items deferred to Phase 4 (Final Code Review) for manual review

### Test results

- All 13 regression tests pass (0 failures)
- test_bump.sh: 44/44, test_bump_advanced.sh: 18/18

### Key commits (from prior branch, now merged)

- `ceffd26` Improve code documentation and readability (Phase 4)
- `d68bf8c` Fix critical bugs, harden security, and refactor codebase

---

## Phase 3D: Add Soft Check Functions

**Status:** Complete

**Date completed:** 2026-01-31

### What was done

Four non-fatal ("soft") variants of existing hard-check functions were implemented
using strict TDD: tests written first, verified to fail, then function implemented,
verified to pass. Each soft function returns an error code instead of calling
`cleanup()`, enabling use in `if/then` conditional logic.

#### 1. soft_not_empty (bump.sh, after not_empty, line ~130)

```bash
function soft_not_empty {
    local sne_description="$1"
    local sne_check="$2"
    if [[ -z "$sne_check" ]]; then
        echo "${STAMP}: cannot run without ${sne_description}" >&2
        return ${MISSING_INPUT}
    fi
    return 0
}
```

- Returns `MISSING_INPUT` (60) when value is empty
- No `log_setting` calls (matching `not_empty` which also has none)
- Tests: 6 assertions in test_bump.sh Test 14

#### 2. soft_check_exists (bump.sh, after check_exists, line ~208)

```bash
function soft_check_exists {
    local sce_file_name="$1"
    log_setting "file or directory name that must exist" "$sce_file_name"
    if [[ ! -e "$sce_file_name" ]]; then
        echo "${STAMP}: cannot find $sce_file_name" >&2
        return ${MISSING_FILE}
    fi
    return 0
}
```

- Returns `MISSING_FILE` (61) when path does not exist
- Includes `log_setting` call (matching hard version)
- Tests: 6 assertions in test_bump.sh Test 15

#### 3. soft_check_dependency (bump.sh, after check_dependency, line ~341)

```bash
function soft_check_dependency {
    local scd_cmd="$1"
    log_setting "command to check for is" "${scd_cmd}"
    if ! command -v "${scd_cmd}" >/dev/null 2>&1; then
        echo "${STAMP}: looking for ${scd_cmd} but it is not available" >&2
        return ${MISSING_CMD}
    fi
    return 0
}
```

- Returns `MISSING_CMD` (65) when command not in PATH
- Includes `log_setting` call (matching hard version)
- Tests: 4 assertions in test_bump.sh Test 16

#### 4. soft_check_contains (bump.sh, after check_contains, line ~307)

```bash
function soft_check_contains {
    local scc_file_name="$1"
    local scc_string="$2"
    soft_not_empty "date stamp" "$STAMP" || return $?
    log_setting "file name to check" "$scc_file_name"
    log_setting "string to check for" "$scc_string"
    if [[ -e "$scc_file_name" ]]; then
        if ! grep -qsF "${scc_string}" "${scc_file_name}"; then
            echo "${STAMP}: ${scc_file_name} does not contain ${scc_string}" >&2
            return ${BAD_CONFIGURATION}
        fi
    else
        echo "${STAMP}: cannot find ${scc_file_name}" >&2
        return ${MISSING_FILE}
    fi
    return 0
}
```

- Returns `BAD_CONFIGURATION` (70) when string not found, `MISSING_FILE` (61) when file missing
- Uses `soft_not_empty` (not `not_empty`) to check STAMP, avoiding accidental cleanup
- Key design decision: `soft_not_empty` check placed BEFORE `log_setting` calls because
  `log_setting` internally calls `not_empty` (hard version) which would trigger cleanup
  when STAMP is empty. This ordering ensures the soft check catches the empty STAMP first.
- Tests: 10 assertions in test_bump.sh Test 17

### Files changed

| File | Changes |
|---|---|
| `bump.sh` | Added 4 soft_ functions with full docstrings, placed after their hard counterparts |
| `test_bump.sh` | Added Tests 14-17 (26 total assertions for soft_ functions) |
| `PLAN.md` | Marked all 3D tasks and review checklist complete |
| `CLAUDE.md` | Added soft_ functions to Key Functions, documented hard/soft/parallel pattern (local only, gitignored) |

### Key decisions

1. **Placement:** Each soft_ function placed immediately after its hard counterpart in bump.sh
2. **log_setting included:** Soft functions include `log_setting` calls like hard versions (unlike parallel_ versions which minimize logging)
3. **soft_not_empty before log_setting:** In `soft_check_contains`, the `soft_not_empty "date stamp"` check must come before any `log_setting` calls to prevent the hard `not_empty` inside `log_setting` from calling cleanup
4. **No new return codes:** All error codes already existed in return_codes.sh (MISSING_INPUT=60, MISSING_FILE=61, MISSING_CMD=65, BAD_CONFIGURATION=70)
5. **Variable naming:** Follows existing prefix convention (sne_, sce_, scd_, scc_)

### Test results

- test_bump.sh: 17 tests, 70/70 assertions pass (including 26 new soft_ assertions)
- test_bump_advanced.sh: 6 tests, 18/18 assertions pass
- test_regression.sh: 13 tests, 23/23 assertions pass
- **Total: 111 assertions, all passing**

### Commits

- `677e8c0` Add tests for soft_not_empty function
- `80f2d6a` Implement soft_not_empty function
- `e20d1b5` Add tests for soft_check_exists function
- `f77ee90` Implement soft_check_exists function
- `0416158` Add tests for soft_check_dependency function
- `bea4b9f` Implement soft_check_dependency function
- `4abc1a0` Add tests for soft_check_contains function
- `adb3e35` Implement soft_check_contains function
- `81bc3cc` Mark Phase 3D tasks complete in PLAN.md
