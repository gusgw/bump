#!/bin/bash
# return_codes.sh: Standardized exit codes for bump utility scripts
#
# This file defines consistent exit codes used across all bump utilities.
# Exit codes are grouped by category to help identify the type of failure.
#
# Usage: Source this file before bump.sh
#   . /path/to/return_codes.sh
#
# Exit Code Ranges:
#   60-69: Missing resources (files, commands, etc.)
#   70-79: Configuration and safety issues
#   80-89: System and infrastructure failures
#   110-119: Signal handling

# Missing Resources (60-69)
# These codes indicate that a required resource could not be found
MISSING_INPUT=60      # Required input parameter was not provided
MISSING_FILE=61       # Required file does not exist
MISSING_FOLDER=62     # Required directory does not exist
MISSING_DISK=63       # Required disk or device not available
MISSING_MOUNT=64      # Required mount point not mounted
MISSING_CMD=65        # Required command not found in PATH

# Configuration and data Issues (70-79)
# These codes indicate problems with configuration or data or safety checks
BAD_CONFIGURATION=70  # Configuration file or setting is invalid
UNSAFE=71             # Operation deemed unsafe to proceed
CORRUPT_DATA=72       # Not continuing due to corrupt data

# System Failures (80-89)
# These codes indicate system-level failures
SYSTEM_UNIT_FAILURE=80  # Systemd unit or service failure
SECURITY_FAILURE=81     # Security check or permission failure
NETWORK_ERROR=83        # Network connectivity or remote resource failure
FILING_ERROR=84         # Error from routine file management

# Signal Handling (110-119)
# These codes are used when handling system signals
TRAPPED_SIGNAL=113    # Generic trapped signal (SIGINT, SIGTERM, etc.)
SHUTDOWN_SIGNAL=114   # Graceful shutdown signal received
