#!/bin/bash
# run_coverage.sh: Run test suite with coverage measurement
#
# Usage: ./run_coverage.sh [test_file]
#
# If no test file specified, runs full test suite.
# Coverage report will be generated in ./coverage/

# Ensure bashcov is in PATH
if ! command -v bashcov >/dev/null 2>&1; then
    export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
fi

# Check if bashcov is available
if ! command -v bashcov >/dev/null 2>&1; then
    echo "Error: bashcov not found. Install with: gem install bashcov"
    exit 1
fi

# Determine what to run
if [[ -n "$1" ]]; then
    TEST_CMD="$1"
    echo "Running coverage on: $TEST_CMD"
else
    TEST_CMD="./run_all_tests.sh"
    echo "Running coverage on full test suite"
fi

# Run with coverage
echo "=========================================="
echo "Generating coverage report..."
echo "=========================================="

bashcov --root "$PWD" "$TEST_CMD"

rc=$?

echo ""
echo "=========================================="
echo "Coverage report generated in: ./coverage/"
echo "Open coverage/index.html in a browser to view"
echo "=========================================="

exit $rc
