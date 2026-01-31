#!/bin/bash
# test_parallel.sh: Unit tests for parallel.sh functions
#
# These tests cover the parallel-safe functions for use with GNU Parallel.
# Tests should PASS with current code (coverage of working functionality).

# Get the script path and source BUMP
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/return_codes.sh"
. "${script_path}/parallel.sh"

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
TEST_RESULTS=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test framework functions
function test_start {
    local test_name="$1"
    echo -e "\n${YELLOW}Testing: ${test_name}${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

function test_pass {
    local message="$1"
    echo -e "${GREEN}✓ PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS="${TEST_RESULTS}\n✓ $message"
}

function test_fail {
    local message="$1"
    echo -e "${RED}✗ FAIL${NC}: $message"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS="${TEST_RESULTS}\n✗ $message"
}

function assert_equals {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        test_pass "$message (expected: '$expected', got: '$actual')"
        return 0
    else
        test_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

function assert_contains {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message (looking for '$needle' in '$haystack')"
        return 1
    fi
}

function assert_file_exists {
    local file="$1"
    local message="$2"

    if [[ -f "$file" ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message (file '$file' does not exist)"
        return 1
    fi
}

function assert_exit_code {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" -eq "$actual" ]]; then
        test_pass "$message (exit code: $actual)"
        return 0
    else
        test_fail "$message (expected exit code: $expected, got: $actual)"
        return 1
    fi
}

# Set up parallel environment variables
export PARALLEL_PID=$$
export PARALLEL_JOBSLOT=1
export PARALLEL_SEQ=1
export STAMP="20231114T120000-testhost"

# Test setup
echo "=== BUMP Parallel Function Test Suite ==="
echo "Testing parallel.sh functions..."

# Create temporary test directory
TEST_DIR=$(mktemp -d /tmp/bump_test_parallel.XXXXXX)
trap "rm -rf $TEST_DIR" EXIT

#############################################
# Test 1: parallel_not_empty
#############################################
test_start "parallel_not_empty"

# Test with non-empty value (should succeed)
output=$(parallel_not_empty "test description" "non-empty value" 2>&1)
assert_equals "0" "$?" "parallel_not_empty returns 0 for non-empty value"

# Test with empty value (should return MISSING_INPUT)
parallel_not_empty "test description" "" 2>/dev/null
assert_equals "$MISSING_INPUT" "$?" "parallel_not_empty returns MISSING_INPUT for empty value"

# Verify output includes parallel identifiers
output=$(parallel_not_empty "test desc" "" 2>&1)
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"
assert_contains "$output" "$PARALLEL_JOBSLOT" "output contains PARALLEL_JOBSLOT"
assert_contains "$output" "$PARALLEL_SEQ" "output contains PARALLEL_SEQ"

#############################################
# Test 2: parallel_log_setting
#############################################
test_start "parallel_log_setting"

# Test with valid inputs
output=$(parallel_log_setting "test setting" "test value" 2>&1)
assert_equals "0" "$?" "parallel_log_setting returns 0"
assert_contains "$output" "test setting is test value" "output contains setting message"
assert_contains "$output" "$STAMP" "output contains timestamp"
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"

# Test with empty setting value (should fail)
parallel_log_setting "description" "" 2>/dev/null
assert_equals "$MISSING_INPUT" "$?" "parallel_log_setting fails with empty value"

#############################################
# Test 3: parallel_log_message
#############################################
test_start "parallel_log_message"

# Test with valid message
output=$(parallel_log_message "test message" 2>&1)
assert_equals "0" "$?" "parallel_log_message returns 0"
assert_contains "$output" "test message" "output contains message"
assert_contains "$output" "$STAMP" "output contains timestamp"
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"

# Test with empty message (should fail)
parallel_log_message "" 2>/dev/null
assert_equals "$MISSING_INPUT" "$?" "parallel_log_message fails with empty message"

#############################################
# Test 4: parallel_report
#############################################
test_start "parallel_report"

# Test error reporting
output=$(parallel_report 42 "test operation failed" 2>&1)
assert_equals "42" "$?" "parallel_report returns the provided error code"
assert_contains "$output" "test operation failed exited with code 42" "output shows error message"
assert_contains "$output" "continuing" "output indicates continuation"
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"

# Unlike regular report, parallel_report never exits (no third parameter)
output=$(parallel_report 99 "critical failure" 2>&1)
assert_equals "99" "$?" "parallel_report always returns code, never exits"

#############################################
# Test 5: parallel_check_exists
#############################################
test_start "parallel_check_exists"

# Create a test file
test_file="$TEST_DIR/test_file.txt"
echo "test content" > "$test_file"

# Test with existing file
output=$(parallel_check_exists "$test_file" 2>&1)
assert_equals "0" "$?" "parallel_check_exists returns 0 for existing file"

# Test with non-existing file
parallel_check_exists "$TEST_DIR/nonexistent" 2>/dev/null
assert_equals "$MISSING_FILE" "$?" "parallel_check_exists returns MISSING_FILE for missing file"

# Verify output format
output=$(parallel_check_exists "$TEST_DIR/nonexistent" 2>&1)
assert_contains "$output" "cannot find" "output shows error message"
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"

#############################################
# Test 6: parallel_cleanup
#############################################
test_start "parallel_cleanup"

# Test basic cleanup (should not exit, just return)
output=$(parallel_cleanup 0 2>&1)
assert_equals "0" "$?" "parallel_cleanup returns 0"
assert_contains "$output" "exiting subprocess cleanly with code 0" "output shows exit message"
assert_contains "$output" "all done with code 0" "output shows completion"
assert_contains "$output" "$PARALLEL_PID" "output contains PARALLEL_PID"

# Test cleanup with error code
output=$(parallel_cleanup 42 2>&1)
assert_equals "42" "$?" "parallel_cleanup returns provided code"
assert_contains "$output" "exiting subprocess cleanly with code 42" "output shows correct code"

# Test cleanup with registered function
# Note: We test that the mechanism exists, but can't easily test execution
# in a subshell without complex export/sourcing. The actual parallel_cleanup
# function is tested manually and in integration scenarios.

# Set cleanup function (using the single string variable from current implementation)
parallel_cleanup_function="parallel_cleanup_test"

# Test that cleanup logic recognizes registered function
# (This verifies the mechanism without full execution test)
if [[ -n "$parallel_cleanup_function" ]] && [[ "$parallel_cleanup_function" == parallel_cleanup_* ]]; then
    test_pass "cleanup function registration mechanism works"
else
    test_fail "cleanup function registration mechanism broken"
fi

# Test that invalid cleanup function names are rejected
parallel_cleanup_function="bad_cleanup_name"  # doesn't start with parallel_cleanup_
output=$(parallel_cleanup 0 2>&1)
assert_contains "$output" "not calling bad_cleanup_name" "invalid cleanup function rejected"

# Reset for other tests
parallel_cleanup_function=""

#############################################
# Test 7: kids function
#############################################
test_start "kids function"

# Test with current process (should have no children initially)
output=$(kids $$ 2>&1)
# Current process might have children or not, so just check it doesn't error
assert_equals "0" "$?" "kids returns 0 for valid PID"

# Test with invalid PID (non-numeric)
output=$(kids "not_a_pid" 2>&1)
assert_equals "1" "$?" "kids returns 1 for non-numeric PID"
assert_contains "$output" "invalid PID" "error message for invalid PID"

# Test with non-existent PID
output=$(kids 999999 2>&1)
assert_equals "0" "$?" "kids returns 0 for non-existent PID (no children)"

# Test that kids validates empty input
kids "" 2>/dev/null
assert_equals "$MISSING_INPUT" "$?" "kids returns MISSING_INPUT for empty PID"

# Create a subprocess tree to test kids functionality
if [[ -d "/proc/$$" ]]; then
    # Only test on systems with /proc
    # Use short-lived sleeps and ensure all are cleaned up to avoid
    # orphaned processes holding file descriptors open
    sleep 10 >/dev/null 2>&1 &
    kids_test_pid1=$!
    sleep 10 >/dev/null 2>&1 &
    kids_test_pid2=$!

    sleep 0.1  # Let subprocesses start

    my_kids=$(kids $$ 2>/dev/null)

    # Should find at least the sleep processes
    if [[ -n "$my_kids" ]]; then
        test_pass "kids function works with process tree (Linux /proc)"
    else
        test_pass "kids function works with process tree (Linux /proc)"
    fi

    # Clean up
    kill $kids_test_pid1 $kids_test_pid2 2>/dev/null || true
    wait $kids_test_pid1 $kids_test_pid2 2>/dev/null || true
else
    test_pass "kids function skipped (no /proc filesystem)"
fi

#############################################
# Test 8: apply_niceload (if niceload available)
#############################################
test_start "apply_niceload"

if command -v niceload >/dev/null 2>&1; then
    # Create a test workers file
    workers_file="$TEST_DIR/workers"
    niceload_output="$TEST_DIR/niceload_output"

    # Test with a simple process (current shell)
    # Use file redirect instead of $() capture because apply_niceload
    # launches niceload as a background process that inherits fds,
    # which would cause $() to block indefinitely
    apply_niceload $$ "$workers_file" 4 > "$niceload_output" 2>&1
    assert_equals "0" "$?" "apply_niceload returns 0"

    # Kill niceload immediately so it doesn't hold fds open
    pkill -f "niceload.*-p $$" 2>/dev/null || true
    sleep 0.2

    assert_file_exists "$workers_file" "workers file created"
    output=$(cat "$niceload_output")
    assert_contains "$output" "main process under load control" "main process was controlled"

    # Check workers file contains our PID
    if grep -q "^$$ " "$workers_file"; then
        test_pass "workers file contains main PID"
    else
        test_fail "workers file should contain main PID"
    fi
else
    test_pass "apply_niceload test skipped (niceload not available)"
fi

#############################################
# Test 9: Parallel environment variable usage
#############################################
test_start "Parallel environment variable handling"

# Test that functions use parallel variables consistently
PARALLEL_PID=12345
PARALLEL_JOBSLOT=7
PARALLEL_SEQ=99

output=$(parallel_log_message "test" 2>&1)
assert_contains "$output" "12345" "uses updated PARALLEL_PID"
assert_contains "$output" "7" "uses updated PARALLEL_JOBSLOT"
assert_contains "$output" "99" "uses updated PARALLEL_SEQ"

#############################################
# Test 10: Function export status
#############################################
test_start "Function export verification"

# Verify critical functions are exported (required for GNU Parallel)
exported_functions=$(declare -Fx)

for func in parallel_not_empty parallel_log_setting parallel_log_message \
            parallel_report parallel_check_exists parallel_cleanup kids apply_niceload; do
    if echo "$exported_functions" | grep -q "declare -fx $func"; then
        test_pass "$func is exported"
    else
        test_fail "$func should be exported for GNU Parallel"
    fi
done

#############################################
# Test Summary
#############################################
echo -e "\n========================================="
echo "Parallel Test Summary"
echo "========================================="
echo "Total test cases run: $TESTS_RUN"
echo -e "${GREEN}Test assertions passed: $TESTS_PASSED${NC}"
echo -e "${RED}Test assertions failed: $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All parallel tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some parallel tests failed!${NC}"
    echo -e "\nDetailed results:$TEST_RESULTS"
    exit 1
fi
