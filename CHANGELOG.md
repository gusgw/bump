# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-11-21

### Fixed
- **Critical**: Fixed `slow` function to use exact process name matching (`pgrep -x`) and restrict to current user (`-u`), preventing hangs on system processes or partial matches.
- **Security**: Fixed regex injection vulnerability in `check_contains` by using fixed-string matching (`grep -F`).
- **Security**: Fixed potential command injection in `apply_niceload` by stricter validation of `OPT_NICELOAD` and quoting variables.
- **Stability**: Fixed recursion vulnerability in `cleanup` function by adding a re-entrance guard.
- **Stability**: Fixed unvalidated file write operations in `load_report`, `memory_report`, and `free_memory_report`.
- **Bug**: Fixed `log_message` parameter validation (was checking "date stamp" instead of "message").
- **Bug**: Fixed `check_dependency` to correctly return error codes for missing commands.

### Added
- **Tests**: Added comprehensive regression test suite (`test_regression.sh`) covering all identified bugs.
- **Tests**: Added `test_check_dependency.sh` for dependency checking verification.
- **Documentation**: Improved documentation for `report` function to clarify exit vs. continue behavior.

### Changed
- Updated `check_dependency` to explicitly return `MISSING_CMD` error code.
- Improved `apply_niceload` to allow spaces in options while preventing injection.

## [1.0.0] - 2023-11-14
- Initial release of BUMP (Bash Utility for Monitoring Processes).
