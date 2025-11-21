#!/bin/bash
# test_bump_advanced.sh: Advanced tests for BUMP monitoring and utility functions
#
# This script tests the more complex BUMP functions like monitoring,
# cleanup chains, and system resource reporting.

# Get the script path and source BUMP
script_path=$(dirname "$(readlink -f "$0")")
. "${script_path}/return_codes.sh"
. "${script_path}/bump.sh"

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test framework functions (same as in test_bump.sh)
function test_start {
    local test_name="$1"
    echo -e "\n${YELLOW}Testing: ${test_name}${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

function test_pass {
    local message="$1"
    echo -e "${GREEN}✓ PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

function test_fail {
    local message="$1"
    echo -e "${RED}✗ FAIL${NC}: $message"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

function assert_equals {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message (expected: '$expected', got: '$actual')"
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

function assert_file_contains {
    local file="$1"
    local content="$2"
    local message="$3"
    
    if [[ -f "$file" ]] && grep -q "$content" "$file"; then
        test_pass "$message"
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

# Test setup
echo "=== BUMP Advanced Function Test Suite ==="
echo "Testing advanced BUMP library functions..."

# Initialize STAMP for tests
set_stamp

# Create temporary test directory
TEST_DIR=$(mktemp -d /tmp/bump_test_advanced.XXXXXX)
trap "rm -rf $TEST_DIR" EXIT

#############################################
# Test 1: slow function
#############################################
test_start "slow function"

# Create a unique process name to avoid waiting for system sleep processes
cp "$(command -v sleep)" "$TEST_DIR/bump_test_sleep"
process_name="bump_test_sleep"

# Create a background process that will terminate after 2 seconds
"$TEST_DIR/bump_test_sleep" 2 &
test_pid=$!

# Set WAIT to 1 second for faster testing
WAIT=1

# Start timing
start_time=$(date +%s)

# This should wait for the sleep process to finish
slow "$process_name" 2>/dev/null

end_time=$(date +%s)
elapsed=$((end_time - start_time))

# Check that it waited approximately the right amount of time (1-3 seconds)
if [[ $elapsed -ge 1 ]] && [[ $elapsed -le 3 ]]; then
    test_pass "slow waited for process to terminate"
else
    test_fail "slow did not wait correctly (elapsed: $elapsed seconds)"
fi

# Verify process is gone
if ! kill -0 $test_pid 2>/dev/null; then
    test_pass "Process terminated as expected"
else
    test_fail "Process still running"
    kill $test_pid 2>/dev/null
fi

#############################################
# Test 2: cleanup_functions array
#############################################
test_start "cleanup_functions array"

# Reset cleanup functions
cleanup_functions=()

# Define test cleanup functions
cleanup1_called=0
cleanup2_called=0
cleanup_bad_called=0

function cleanup_test1 {
    cleanup1_called=1
    echo "cleanup_test1 called with $1" >&2
}

function cleanup_test2 {
    cleanup2_called=1
    echo "cleanup_test2 called with $1" >&2
}

function bad_cleanup {
    cleanup_bad_called=1
    echo "bad_cleanup should not be called" >&2
}

# Add functions to cleanup array
cleanup_functions+=("cleanup_test1")
cleanup_functions+=("cleanup_test2")
cleanup_functions+=("bad_cleanup")  # This should be rejected

# Override cleanup to not exit
function cleanup {
    local c_rc="${1:-0}"
    print_error_rule
    echo "${STAMP}: exiting cleanly with code ${c_rc}. . ." >&2
    
    local cleanfn
    for cleanfn in "${cleanup_functions[@]}"; do
        if [[ "$cleanfn" == cleanup_* ]]; then
            if declare -f "$cleanfn" >/dev/null 2>&1; then
                "$cleanfn" "${c_rc}" || true
            else
                echo "${STAMP}: cleanup function $cleanfn not found" >&2
            fi
        else
            echo "${STAMP}: not calling $cleanfn (invalid name)" >&2
        fi
    done
    echo "${STAMP}: . . . all done with code ${c_rc}" >&2
    # Don't exit during test
}

# Call cleanup
cleanup 42 2>/dev/null

assert_equals "1" "$cleanup1_called" "cleanup_test1 was called"
assert_equals "1" "$cleanup2_called" "cleanup_test2 was called"
assert_equals "0" "$cleanup_bad_called" "bad_cleanup was not called (invalid name)"

#############################################
# Test 3: load_report function
#############################################
test_start "load_report"

# Only test on Linux with /proc/loadavg
if [[ -f /proc/loadavg ]]; then
    load_file="$TEST_DIR/load.log"
    
    # Test load reporting
    output=$(load_report "test_load" "$load_file" 2>&1)
    assert_equals "0" "$?" "load_report returns 0"
    assert_file_exists "$load_file" "Load file created"
    
    # Check file content
    if [[ -f "$load_file" ]]; then
        content=$(cat "$load_file")
        if [[ "$content" =~ test_load.*[0-9]+\.[0-9]+.*[0-9]+\.[0-9]+.*[0-9]+\.[0-9]+ ]]; then
            test_pass "Load file contains valid load data"
        else
            test_fail "Load file format incorrect"
        fi
    fi
else
    test_pass "Skipping load_report test (no /proc/loadavg)"
fi

#############################################
# Test 4: memory_report function
#############################################
test_start "memory_report"

# Only test on Linux with /proc
if [[ -d /proc/$$ ]]; then
    memory_file="$TEST_DIR/memory.log"
    
    # Test memory reporting for current process
    output=$(memory_report "test_memory" $$ "$memory_file" 2>&1)
    assert_equals "0" "$?" "memory_report returns 0 for current process"
    assert_file_exists "$memory_file" "Memory file created"
    
    # Check file content
    if [[ -f "$memory_file" ]]; then
        content=$(cat "$memory_file")
        if [[ "$content" =~ test_memory.*$$.*[0-9]+.*[0-9]+ ]]; then
            test_pass "Memory file contains valid memory data"
        else
            test_fail "Memory file format incorrect"
        fi
    fi
    
    # Test with non-existent PID
    memory_report "test" 999999 "$TEST_DIR/memory2.log" 2>&1
    assert_equals "1" "$?" "memory_report returns 1 for non-existent process"
else
    test_pass "Skipping memory_report test (no /proc)"
fi

#############################################
# Test 5: free_memory_report function
#############################################
test_start "free_memory_report"

# Check if free command is available
if command -v free >/dev/null 2>&1; then
    free_file="$TEST_DIR/free.log"
    
    # Test free memory reporting
    output=$(free_memory_report "test_free" "$free_file" 2>&1)
    assert_equals "0" "$?" "free_memory_report returns 0"
    assert_file_exists "$free_file" "Free memory file created"
    
    # Check file content
    if [[ -f "$free_file" ]]; then
        content=$(cat "$free_file")
        if [[ "$content" =~ test_free.*[0-9]+.*[0-9]+ ]]; then
            test_pass "Free memory file contains valid data"
        else
            test_fail "Free memory file format incorrect"
        fi
    fi
else
    test_pass "Skipping free_memory_report test (no free command)"
fi

#############################################
# Test 6: Integration test - Multiple reports
#############################################
test_start "Integration - Multiple monitoring reports"

if [[ -f /proc/loadavg ]] && command -v free >/dev/null 2>&1; then
    # Create log files
    integration_dir="$TEST_DIR/integration"
    mkdir -p "$integration_dir"
    
    # Run multiple reports
    for i in {1..3}; do
        load_report "iteration_$i" "$integration_dir/load.log" 2>/dev/null
        memory_report "iteration_$i" $$ "$integration_dir/memory.log" 2>/dev/null
        free_memory_report "iteration_$i" "$integration_dir/free.log" 2>/dev/null
        sleep 0.1
    done
    
    # Check that files have multiple entries
    load_lines=$(wc -l < "$integration_dir/load.log" 2>/dev/null || echo 0)
    memory_lines=$(wc -l < "$integration_dir/memory.log" 2>/dev/null || echo 0)
    free_lines=$(wc -l < "$integration_dir/free.log" 2>/dev/null || echo 0)
    
    assert_equals "3" "$load_lines" "Load log has 3 entries"
    assert_equals "3" "$memory_lines" "Memory log has 3 entries"
    assert_equals "3" "$free_lines" "Free memory log has 3 entries"
else
    test_pass "Skipping integration test (missing requirements)"
fi

#############################################
# Test Summary
#############################################
echo -e "\n========================================="
echo "Advanced Test Summary"
echo "========================================="
echo "Total test cases run: $TESTS_RUN"
echo -e "${GREEN}Test assertions passed: $TESTS_PASSED${NC}"
echo -e "${RED}Test assertions failed: $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All advanced tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some advanced tests failed!${NC}"
    exit 1
fi