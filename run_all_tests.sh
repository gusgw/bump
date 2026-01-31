#!/bin/bash
# run_all_tests.sh: Master test runner for BUMP test suite
#
# Runs all test files and provides a comprehensive summary.
# Usage: ./run_all_tests.sh [--verbose]

set -e  # Exit on error (except for expected test failures)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

VERBOSE=0
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=1
fi

# Get script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}BUMP Test Suite - Running All Tests${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "Test directory: $SCRIPT_DIR"
echo "Started at: $(date)"
echo ""

# Array to store test results
declare -a TEST_RESULTS

# Function to run a test suite
function run_test_suite() {
    local test_file="$1"
    local test_name="$2"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}Running: $test_name${NC}"
    echo -e "${BOLD}File: $test_file${NC}"
    echo -e "${BOLD}========================================${NC}"

    local exit_code
    local tmpfile

    if [[ $VERBOSE -eq 1 ]]; then
        "./$test_file"
        exit_code=$?
    else
        # Quiet mode - capture output to temp file
        tmpfile=$(mktemp)
        "./$test_file" > "$tmpfile" 2>&1
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
        echo -e "${GREEN}✓ SUITE PASSED${NC}: $test_name"
        TEST_RESULTS+=("${GREEN}✓ PASS${NC}: $test_name")

        if [[ $VERBOSE -eq 0 ]]; then
            # Show summary in quiet mode
            grep -E "(Test (Summary|assertions)|All .* passed)" "$tmpfile" || true
        fi
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
        echo -e "${RED}✗ SUITE FAILED${NC}: $test_name"
        TEST_RESULTS+=("${RED}✗ FAIL${NC}: $test_name")
    fi

    # Clean up temp file
    [[ -n "${tmpfile:-}" ]] && rm -f "$tmpfile"
}


# Check if test files exist
if [[ ! -f "test_bump.sh" ]]; then
    echo -e "${RED}Error: test_bump.sh not found${NC}"
    exit 1
fi

# Make all test files executable
chmod +x test_bump.sh test_bump_advanced.sh test_parallel.sh test_coverage.sh test_regression.sh 2>/dev/null || true

# Run existing test suites (should pass)
echo -e "${BOLD}=== Phase 1: Existing Tests (Should Pass) ===${NC}"
echo ""

if [[ -f "test_bump.sh" ]]; then
    run_test_suite "test_bump.sh" "Basic Unit Tests"
fi

if [[ -f "test_bump_advanced.sh" ]]; then
    run_test_suite "test_bump_advanced.sh" "Advanced Monitoring Tests"
fi

# Run new coverage tests (should pass)
echo ""
echo -e "${BOLD}=== Phase 2: New Coverage Tests (Should Pass) ===${NC}"
echo ""

if [[ -f "test_parallel.sh" ]]; then
    run_test_suite "test_parallel.sh" "Parallel Functions Tests"
fi

if [[ -f "test_coverage.sh" ]]; then
    run_test_suite "test_coverage.sh" "Additional Coverage Tests"
fi

# Run regression tests
echo ""
echo -e "${BOLD}=== Phase 3: Regression Tests ===${NC}"
echo ""

if [[ -f "test_regression.sh" ]]; then
    run_test_suite "test_regression.sh" "Bug Regression Tests"
fi

# Print overall summary
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}Overall Test Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "Completed at: $(date)"
echo ""
echo "Total test suites run: $TOTAL_SUITES"
echo -e "${GREEN}Suites passed: $PASSED_SUITES${NC}"
echo -e "${RED}Suites failed: $FAILED_SUITES${NC}"
echo ""

echo -e "${BOLD}Individual Suite Results:${NC}"
for result in "${TEST_RESULTS[@]}"; do
    echo -e "  $result"
done
echo ""

# Determine exit code
if [[ $FAILED_SUITES -gt 0 ]]; then
    echo -e "${RED}Some test suites failed - this needs attention!${NC}"
    exit 1
else
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
fi
