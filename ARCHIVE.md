# Archive

Historical reference material from the BUMP project development process.
This file preserves concise summaries of documents that were removed during
file consolidation.

---

## Test Coverage

### Tools

**bashcov** (v3.2.0) measures line coverage for bash scripts.

```bash
# Installation
gem install bashcov

# The executable installs to ~/.local/share/gem/ruby/VERSION/bin/
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"

# Run coverage on full test suite
bashcov --bash-path /usr/bin/bash --root "$PWD" ./run_all_tests.sh

# Run on a specific test file
bashcov --bash-path /usr/bin/bash --root "$PWD" ./test_bump.sh

# View results
xdg-open coverage/index.html
```

**Limitations:** bashcov adds 15-20x overhead (a 2s test takes 30s). It also
undercounts coverage for sourced files and subprocess-based tests. The
`test_parallel.sh` suite times out under bashcov due to sleep-based tests
combined with this overhead.

**Alternative tools to consider:** kcov (C-based, may be faster), shcov
(pure bash), shellspec (has built-in coverage).

### Coverage Results (2025-11-14)

| File | Coverage | Lines |
|---|---|---|
| bump.sh | 78.89% | 157/199 relevant lines |
| return_codes.sh | 100% | 15/15 |
| parallel.sh | Not measured (fully tested, bashcov too slow) |

The 21% uncovered in bump.sh consists of:
- Rare error paths (~10%): command failures in md5sum/awk/grep
- Platform-specific code (~5%): fallbacks for different `free` versions, /proc variations
- Defensive code (~4%): safety checks in error handlers
- Error-in-error scenarios (~2%): failures during cleanup/signal handling

### Test Suite Statistics (at end of Phase 2)

| Test File | Cases | Assertions | Status |
|---|---|---|---|
| test_bump.sh | 13 | 45 | All pass |
| test_bump_advanced.sh | 6 | 17 | All pass (1 flaky timing test) |
| test_parallel.sh | 10 | 50 | All pass |
| test_coverage.sh | 23 | 95 | All pass |
| test_regression.sh | 12 | 20 | 15 pass, 5 expected failures |
| **Total** | **64** | **227** | |

After Phase 3D (soft checks), test_bump.sh grew to 17 cases / 71 assertions,
bringing the total to 111 assertions across the main three test files.

---

## Regression Test Coverage

Regression tests (test_regression.sh) cover 12 bug scenarios identified
during code review. Each test was written to fail before the fix and pass
after, following TDD methodology.

| Bug | Severity | Description | Test Status |
|---|---|---|---|
| BUG 1 (H1) | High | log_message validates wrong parameter | Fixed in Phase 3A |
| BUG 2 (C2) | Critical | check_contains treats input as regex | Fixed in Phase 3A (uses grep -F) |
| BUG 3 (C3) | Critical | path_as_name fails with newlines in paths | Fixed in Phase 3A |
| BUG 4 (C1) | Critical | apply_niceload command injection | Fixed in Phase 3B |
| BUG 5 (H3) | High | free_memory_report fragile column parsing | Fixed in Phase 3A |
| BUG 6 (H2) | High | poll_reports doesn't validate empty $ramdisk | Fixed in Phase 3A |
| BUG 7 (H4) | High | cleanup function recursion guard | Already working |
| BUG 8-10 (C4) | Critical | Unvalidated file write operations | Fixed in Phase 3B |
| BUG 11 (H5) | High | check_md5 inconsistent error handling | Fixed in Phase 3C |
| BUG 12 (H6) | High | kids() missing PID validation | Fixed in Phase 3B |

---

## Testing Framework Analysis

### Current Framework

Custom bash test framework (no external dependencies) with:
- `assert_equals`, `assert_contains`, `assert_file_exists`, `assert_exit_code`
- Colour output, temp directory isolation, cleanup override mechanism
- 834+ lines of test code across all test files

### Recommendation: Migrate to Bats

**Bats** (Bash Automated Testing System) is the recommended migration target:
- Most popular bash testing framework (~4.7k GitHub stars)
- TAP-compliant output, subprocess isolation per test
- Setup/teardown support, helper libraries (bats-assert, bats-support)
- Used by Docker, Kubernetes, and other major projects
- Low migration effort from current custom framework

```bash
# Installation
git clone https://github.com/bats-core/bats-core.git test/bats
git clone https://github.com/bats-core/bats-support test/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert test/test_helper/bats-assert

# Or: pacman -S bats (Arch), apt install bats (Debian), brew install bats-core (macOS)

# Example test
@test "set_stamp generates valid timestamp" {
    run set_stamp
    assert_success
    assert_regex "$STAMP" '^[0-9]{8}T[0-9]{6}-.*$'
}
```

Other frameworks considered: shUnit2 (xUnit-style, less active), shellspec
(BDD-style, steeper learning curve).

---

## Manual Review Items Summary

17 items were identified during code review. Final disposition:

**Resolved (6 items):**
- M7: strict mode guidance — README Best Practices section
- M9: function examples — README Examples section
- M10: global variables — README Global Variables section
- M13: test isolation — fixed in Phase 0.3 (subprocess approach)
- L2: troubleshooting — README Troubleshooting section
- L4: version number — VERSION variable in bump.sh

**Addressed in Phase 3D branch (3 items):**
- M5: variable naming — soft_ functions use consistent prefixes
- M8: inline comments — complex functions documented
- L1: documentation format — soft_ functions follow consistent format

**Deferred to Future Work (documented in PLAN.md):**
- M1: standardize error reporting across bump.sh/parallel.sh
- M2: add log levels (DEBUG/INFO/WARN/ERROR)
- M3: split report() into report() and fatal()
- M4: add error context stack (BASH_SOURCE/BASH_LINENO)
- M6: standardize quoting style
- M12: add integration tests
- L3: maintain changelog

**No action needed (1 item):**
- M11: poll_reports re-reads workers file — correct behaviour (workers change dynamically)

---

## Phase 4 Code Review Findings

Phase 4 reviewed all files changed on `claude-2-soft_checks` vs `develop`:

- **bump.sh:** 4 soft_ functions added with full docstrings, minor whitespace normalization
- **test_bump.sh:** 4 test cases (Tests 14-17) with 26 assertions, proper cleanup tracking
- **PLAN.md:** Phase 3D tasks added and marked complete
- **PROGRESS.md:** Phase 3D summary with full detail

No debug code, no leftover TODO markers, no style inconsistencies found.
All manual review items assessed — see disposition above.
