#!/bin/bash
# test_bump.sh: Unit tests for BUMP utility functions
#
# This script tests the BUMP library functions to ensure they work correctly.
# It starts with the simplest functions and progresses to more complex ones.

# Get the script path and source BUMP
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/return_codes.sh"
. "${script_path}/bump.sh"

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

# Override cleanup to prevent script exit during tests
original_cleanup=$(declare -f cleanup)
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    # Don't actually exit during tests
    return $c_rc
}

# Test setup
echo "=== BUMP Function Test Suite ==="
echo "Testing BUMP library functions..."

# Create temporary test directory
TEST_DIR=$(mktemp -d /tmp/bump_test.XXXXXX)
trap "rm -rf $TEST_DIR" EXIT

#############################################
# Test 1: set_stamp
#############################################
test_start "set_stamp"

set_stamp
assert_equals "0" "$?" "set_stamp returns 0"
[[ -n "$STAMP" ]] && test_pass "STAMP variable is set" || test_fail "STAMP variable is not set"

# Check timestamp format (YYYYMMDDTHHMMSS-hostname)
if [[ "$STAMP" =~ ^[0-9]{8}T[0-9]{6}-.*$ ]]; then
    test_pass "STAMP has correct format"
else
    test_fail "STAMP format incorrect: $STAMP"
fi

#############################################
# Test 2: set_month
#############################################
test_start "set_month"

set_month
assert_equals "0" "$?" "set_month returns 0"
[[ -n "$MONTH" ]] && test_pass "MONTH variable is set" || test_fail "MONTH variable is not set"

# Check month format (YYYYMM)
if [[ "$MONTH" =~ ^[0-9]{6}$ ]]; then
    test_pass "MONTH has correct format"
else
    test_fail "MONTH format incorrect: $MONTH"
fi

#############################################
# Test 3: print_rule
#############################################
test_start "print_rule"

output=$(print_rule)
assert_equals "0" "$?" "print_rule returns 0"
assert_equals "========================================" "$output" "print_rule outputs default rule"

# Test with custom RULE
RULE="----------"
output=$(print_rule)
assert_equals "----------" "$output" "print_rule outputs custom rule"
RULE="========================================"  # Reset

#############################################
# Test 4: print_error_rule
#############################################
test_start "print_error_rule"

# Capture stderr
output=$(print_error_rule 2>&1)
assert_equals "0" "$?" "print_error_rule returns 0"
assert_equals "========================================" "$output" "print_error_rule outputs to stderr"

#############################################
# Test 5: path_as_name
#############################################
test_start "path_as_name"

# Test various path conversions
result=$(path_as_name "/usr/local/bin")
assert_equals "usr-local-bin" "$result" "path_as_name removes leading slash and converts"

result=$(path_as_name "/path/with spaces/file")
assert_equals "path-with_spaces-file" "$result" "path_as_name handles spaces"

result=$(path_as_name "relative/path")
assert_equals "relative-path" "$result" "path_as_name handles relative paths"

#############################################
# Test 6: log_setting
#############################################
test_start "log_setting"

# Ensure STAMP is set for log_setting
set_stamp

# Capture stderr output
output=$(log_setting "test setting" "test value" 2>&1)
assert_equals "0" "$?" "log_setting returns 0"
assert_contains "$output" "test setting is test value" "log_setting outputs correct message"
assert_contains "$output" "$STAMP" "log_setting includes timestamp"

#############################################
# Test 7: not_empty
#############################################
test_start "not_empty"

# Test with non-empty value (should succeed)
not_empty "test description" "non-empty value" 2>/dev/null
assert_equals "0" "$?" "not_empty returns 0 for non-empty value"

# Test with empty value (should call cleanup)
# We need to capture the cleanup call
cleanup_called=0
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    return 0
}

not_empty "test description" "" 2>/dev/null
assert_equals "1" "$cleanup_called" "not_empty calls cleanup for empty value"
assert_equals "$MISSING_INPUT" "$cleanup_code" "not_empty uses MISSING_INPUT exit code"

# Restore cleanup override
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 8: check_exists with files
#############################################
test_start "check_exists"

# Create a test file
test_file="$TEST_DIR/test_file.txt"
echo "test content" > "$test_file"

# Test with existing file (should succeed)
output=$(check_exists "$test_file" 2>&1)
assert_equals "0" "$?" "check_exists returns 0 for existing file"

# Test with non-existing file (should call cleanup)
cleanup_called=0
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    return 0
}

check_exists "$TEST_DIR/nonexistent" 2>/dev/null
assert_equals "1" "$cleanup_called" "check_exists calls cleanup for missing file"
assert_equals "$MISSING_FILE" "$cleanup_code" "check_exists uses MISSING_FILE exit code"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 9: check_dependency
#############################################
test_start "check_dependency"

# Test with existing command (bash should always exist)
output=$(check_dependency "bash" 2>&1)
assert_equals "0" "$?" "check_dependency returns 0 for existing command"

# Test with non-existing command
# Note: check_dependency calls report which calls cleanup with exit message
cleanup_called=0
cleanup_code=0
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    # Simulate exit behavior without actually exiting
    return $1
}

check_dependency "nonexistent_command_xyz" 2>&1
assert_equals "1" "$cleanup_called" "check_dependency calls cleanup for missing command"
assert_equals "$MISSING_CMD" "$cleanup_code" "check_dependency uses MISSING_CMD exit code"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 10: report function
#############################################
test_start "report"

# Test report without exit (continue)
output=$(report 42 "test operation" 2>&1)
assert_equals "42" "$?" "report returns the provided error code"
assert_contains "$output" "test operation exited with code 42" "report shows error message"
assert_contains "$output" "continuing" "report indicates continuation"

# Test report with exit message (should call cleanup)
cleanup_called=0
cleanup_code=0
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    return 0
}

report 99 "critical failure" "must exit now" 2>/dev/null
assert_equals "1" "$cleanup_called" "report calls cleanup when exit message provided"
assert_equals "99" "$cleanup_code" "report passes correct exit code to cleanup"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 11: check_contains
#############################################
test_start "check_contains"

# Create test file with content
test_file="$TEST_DIR/contains_test.txt"
echo "Line 1: Hello World" > "$test_file"
echo "Line 2: Test Content" >> "$test_file"

# Test with existing string
output=$(check_contains "$test_file" "Hello World" 2>&1)
assert_equals "0" "$?" "check_contains returns 0 when string found"

# Test with missing string (should call cleanup with BAD_CONFIGURATION)
cleanup_called=0
cleanup_code=0
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    return 0
}

check_contains "$test_file" "Missing String" 2>/dev/null
assert_equals "1" "$cleanup_called" "check_contains calls cleanup when string not found"
assert_equals "$BAD_CONFIGURATION" "$cleanup_code" "check_contains uses BAD_CONFIGURATION exit code"

# Test with non-existent file
cleanup_called=0
cleanup_code=0
check_contains "$TEST_DIR/nonexistent_file" "any string" 2>/dev/null
assert_equals "1" "$cleanup_called" "check_contains calls cleanup for missing file"
assert_equals "$MISSING_FILE" "$cleanup_code" "check_contains uses MISSING_FILE for missing file"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 12: check_md5
#############################################
test_start "check_md5"

# Create a test file with known content
test_file="$TEST_DIR/md5_test.txt"
echo -n "Hello, World!" > "$test_file"

# Calculate the actual MD5
actual_md5=$(md5sum "$test_file" | awk '{print $1}')

# Test with correct MD5
output=$(check_md5 "$actual_md5" "$test_file" 2>&1)
assert_equals "0" "$?" "check_md5 returns 0 for correct checksum"
assert_contains "$output" "has correct md5" "check_md5 reports success"

# Test with incorrect MD5
output=$(check_md5 "wrongmd5hash1234567890abcdef1234" "$test_file" 2>&1)
assert_equals "$CORRUPT_DATA" "$?" "check_md5 returns CORRUPT_DATA for wrong checksum"
assert_contains "$output" "wrong md5" "check_md5 reports wrong checksum"

# Test with non-existent file
# The correct behavior (after BUG 11 fix) is that check_md5 returns error codes
# instead of calling cleanup, for consistent error handling
set_stamp

check_md5 "anymd5" "$TEST_DIR/nonexistent_md5_file" 2>&1
rc=$?
assert_equals "$MISSING_FILE" "$rc" "check_md5 returns MISSING_FILE for missing file"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test 13: handle_signal
#############################################
test_start "handle_signal"

# Test signal handler
# Ensure STAMP is set
set_stamp

# Reset and override cleanup
cleanup_called=0
cleanup_code=0

# Create a new cleanup function that tracks calls
function cleanup {
    cleanup_called=1
    cleanup_code=$1
    echo "Test cleanup intercepted signal handler with code $1" >&2
    # Don't exit, just return
    return 0
}

# Export our test variables so they're available in subshell
export cleanup_called cleanup_code

# Test handle_signal - need to ensure our cleanup override is used
output=$(
    cleanup_called=0
    cleanup_code=0
    function cleanup {
        echo "cleanup_called=1" >&2
        echo "cleanup_code=$1" >&2
        echo "Test cleanup intercepted with code $1" >&2
        return 0
    }
    handle_signal 2>&1
)

# Check if cleanup was called by looking for our output
if [[ "$output" == *"cleanup_called=1"* ]]; then
    test_pass "handle_signal calls cleanup"
else
    test_fail "handle_signal calls cleanup"
fi

if [[ "$output" == *"cleanup_code=$TRAPPED_SIGNAL"* ]]; then
    test_pass "handle_signal uses TRAPPED_SIGNAL exit code"
else
    test_fail "handle_signal uses TRAPPED_SIGNAL exit code"
fi

assert_contains "$output" "trapped signal" "handle_signal reports signal"

# Restore cleanup
function cleanup {
    local c_rc="${1:-0}"
    echo "cleanup called with exit code: $c_rc" >&2
    return $c_rc
}

#############################################
# Test Summary
#############################################
echo -e "\n========================================="
echo "Test Summary"
echo "========================================="
echo "Total test cases run: $TESTS_RUN"
echo -e "${GREEN}Test assertions passed: $TESTS_PASSED${NC}"
echo -e "${RED}Test assertions failed: $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    echo -e "\nDetailed results:$TEST_RESULTS"
    exit 1
fi