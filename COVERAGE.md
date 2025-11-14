# Test Coverage Guide

## Overview

BUMP uses bashcov for test coverage measurement. Bashcov tracks which lines of bash code are executed during tests.

## Installation

Bashcov requires Ruby and is installed as a gem:

```bash
gem install bashcov
```

**Dependencies:**
- Ruby 3.0+
- erb gem (install with `gem install erb` if missing)

The bashcov executable will be installed to `~/.local/share/gem/ruby/VERSION/bin/` and needs to be in your PATH.

## Running Coverage

### Quick Start

Use the provided script to run coverage on the full test suite:

```bash
./run_coverage.sh
```

This will:
1. Run all tests through bashcov
2. Generate HTML coverage report in `./coverage/`
3. Display summary statistics

### Run Coverage on Specific Test

```bash
./run_coverage.sh ./test_bump.sh
```

### Manual Usage

```bash
# Ensure bashcov is in PATH
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"

# Run with coverage
bashcov --root "$PWD" ./run_all_tests.sh

# View results
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

## Viewing Reports

Coverage reports are generated in `./coverage/`:
- `coverage/index.html` - Main coverage report with file list
- `coverage/assets/` - CSS and JavaScript for report
- Individual file reports showing line-by-line coverage

**Coverage indicators:**
- 🟢 Green lines - executed during tests
- 🔴 Red lines - not executed during tests
- Gray lines - not executable (comments, blank lines)

## Configuration

Coverage settings are in `.bashcov`:
- `skip_uncovered` - Don't include uncovered files in report
- Output directory can be customized
- Minimum coverage thresholds can be set

## Current Coverage Status

**Baseline:** 19.27% line coverage (270/1401 lines) with test_bump.sh only

**Target:** 90%+ line coverage with full test suite

See PLAN.md Phase 0 for coverage improvement plan.

## Interpreting Results

### Line Coverage Percentage

`(Executed Lines / Total Executable Lines) * 100`

Example: 270 lines executed out of 1401 total = 19.27%

### Per-File Coverage

Bashcov shows coverage for each source file:
- bump.sh - Main utility functions
- parallel.sh - Parallel-safe functions
- return_codes.sh - Constants (should be 100%)

### What Should Be Covered

**High priority:**
- All function entry points
- Error handling paths
- Validation logic
- Critical business logic

**Lower priority:**
- Error messages (text variations)
- Defensive/unreachable code
- Platform-specific fallbacks

## Troubleshooting

### bashcov command not found

Add to PATH:
```bash
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
```

Or add to `~/.bashrc` for persistence.

### Missing erb error

```bash
gem install erb
```

### Coverage seems low

- Are all test files being run?
- Check `./run_all_tests.sh` includes all tests
- Some code paths may only execute in production environments

### hostname command not found

This warning can be ignored. The tests work around it. In production, ensure hostname is available or set the STAMP variable manually.

## Coverage Goals

From PLAN.md Phase 0:

- [ ] 0.2: Measure baseline (full test suite)
- [ ] 0.4: Add tests for uncovered functions
- [ ] 0.5: Add edge case and error path tests
- Target: 90%+ line coverage

## CI/CD Integration

To integrate with CI:

```bash
# Run tests with coverage
./run_coverage.sh

# Check coverage threshold (future enhancement)
# bashcov --minimum-coverage 90 ./run_all_tests.sh
```

## Resources

- [bashcov GitHub](https://github.com/infertux/bashcov)
- [SimpleCov docs](https://github.com/simplecov-ruby/simplecov) (underlying coverage tool)
- PLAN.md - Phase 0 coverage improvement tasks
