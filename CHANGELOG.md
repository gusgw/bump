# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-01-31

### Added
- **Soft check functions**: Four non-fatal variants of existing check functions
  that return error codes instead of exiting, for use in `if/then` conditional logic:
  - `soft_not_empty` — returns `MISSING_INPUT` (60) on failure
  - `soft_check_exists` — returns `MISSING_FILE` (61) on failure
  - `soft_check_dependency` — returns `MISSING_CMD` (65) on failure
  - `soft_check_contains` — returns `BAD_CONFIGURATION` (70) or `MISSING_FILE` (61) on failure
- **Tests**: 26 new test assertions for soft check functions (Tests 14-17 in test_bump.sh)
- **Documentation**: Soft Validation Functions section in README API Reference
- **Documentation**: Production parallel example with load management in README
- **Documentation**: Parallel design pattern diagram and key principles in README
- **Documentation**: Full API reference for `kids()` and `apply_niceload()` in README
- **Documentation**: Future Work section in PLAN.md

### Changed
- README.md substantially expanded with parallel usage guide, soft check documentation
- Consolidated markdown files: removed 8 files, archived relevant content in ARCHIVE.md

## [1.1.0] - 2025-11-21

### Fixed
- **Critical**: Fixed `slow` function to use exact process name matching (`pgrep -x`) and restrict to current user (`-u`), preventing hangs on system processes or partial matches.
- **Security**: Fixed regex injection vulnerability in `check_contains` by using fixed-string matching (`grep -F`).
- **Security**: Fixed unsafe `sed` in `path_as_name` replaced with bash built-in string manipulation.
- **Security**: Fixed potential command injection in `apply_niceload` by stricter validation of `OPT_NICELOAD` and quoting variables.
- **Stability**: Fixed recursion vulnerability in `cleanup` function by adding a re-entrance guard.
- **Stability**: Fixed unvalidated file write operations in `load_report`, `memory_report`, and `free_memory_report`.
- **Bug**: Fixed `log_message` parameter validation (was checking "date stamp" instead of "message").
- **Bug**: Fixed `check_dependency` to correctly return error codes for missing commands.
- **Bug**: Fixed `check_md5` return code handling for missing files.
- **Bug**: Fixed unvalidated `$ramdisk` in `poll_reports`.
- **Bug**: Fixed fragile memory column detection in `free_memory_report`.
- **Bug**: Fixed PID validation ordering in `kids` function.

### Added
- **Tests**: Comprehensive test suite (111 assertions across 3 test suites, all passing)
- **Tests**: Regression test suite (`test_regression.sh`) covering all 13 identified bugs
- **Tests**: Advanced test suite (`test_bump_advanced.sh`) for monitoring functions
- **Documentation**: Comprehensive README with usage guide, API reference, examples, troubleshooting
- **Documentation**: Global variables documentation in README
- **Documentation**: Function docstrings for all functions in bump.sh and parallel.sh

### Changed
- Updated `check_dependency` to explicitly return `MISSING_CMD` error code.
- Improved `apply_niceload` to allow spaces in options while preventing injection.
- Evaluated all 9 "missing" parallel functions — determined none are needed by design.

## [1.0.0] - 2023-11-14
- Initial release of BUMP (Bash Utility for Monitoring Processes).
