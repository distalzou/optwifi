#!/bin/sh
# Test helper functions and mocks

# Test assertion functions
assert_equals() {
	local expected="$1"
	local actual="$2"
	local message="${3:-Assertion failed}"

	if [ "$expected" = "$actual" ]; then
		return 0
	else
		echo "✗ $message"
		echo "  Expected: '$expected'"
		echo "  Actual:   '$actual'"
		return 1
	fi
}

assert_not_equals() {
	local not_expected="$1"
	local actual="$2"
	local message="${3:-Assertion failed}"

	if [ "$not_expected" != "$actual" ]; then
		return 0
	else
		echo "✗ $message"
		echo "  Should not equal: '$not_expected'"
		echo "  But got:          '$actual'"
		return 1
	fi
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	local message="${3:-Assertion failed}"

	case "$haystack" in
		*"$needle"*)
			return 0
			;;
		*)
			echo "✗ $message"
			echo "  Expected to contain: '$needle'"
			echo "  In: '$haystack'"
			return 1
			;;
	esac
}

assert_exit_success() {
	local command="$1"
	local message="${2:-Command should succeed}"

	if eval "$command" >/dev/null 2>&1; then
		return 0
	else
		echo "✗ $message"
		echo "  Command failed: $command"
		return 1
	fi
}

assert_exit_failure() {
	local command="$1"
	local message="${2:-Command should fail}"

	if eval "$command" >/dev/null 2>&1; then
		echo "✗ $message"
		echo "  Command succeeded but should have failed: $command"
		return 1
	else
		return 0
	fi
}

# Mock UCI command
# Reads from a test config file instead of real UCI
uci() {
	local cmd="$1"
	shift

	case "$cmd" in
		get|-q)
			if [ "$1" = "-q" ]; then
				shift
			fi
			local key="$1"
			# Look up in mock config
			if [ -f "$UCI_MOCK_FILE" ]; then
				grep "^${key}=" "$UCI_MOCK_FILE" | cut -d= -f2- | head -1
			fi
			;;
		set)
			local assignment="$1"
			if [ -f "$UCI_MOCK_FILE" ]; then
				local key="${assignment%%=*}"
				local value="${assignment#*=}"
				# Remove old entry and add new one
				grep -v "^${key}=" "$UCI_MOCK_FILE" > "${UCI_MOCK_FILE}.tmp" 2>/dev/null || true
				echo "${key}=${value}" >> "${UCI_MOCK_FILE}.tmp"
				mv "${UCI_MOCK_FILE}.tmp" "$UCI_MOCK_FILE"
			fi
			;;
		show)
			local section="$1"
			if [ -f "$UCI_MOCK_FILE" ]; then
				if [ -n "$section" ]; then
					grep "^${section}\." "$UCI_MOCK_FILE"
				else
					cat "$UCI_MOCK_FILE"
				fi
			fi
			;;
		commit)
			# No-op for mock
			return 0
			;;
		*)
			echo "Mock UCI: unknown command: $cmd" >&2
			return 1
			;;
	esac
}

# Mock logger
logger() {
	# Just echo to a log file for testing
	if [ -n "$LOGGER_MOCK_FILE" ]; then
		echo "$@" >> "$LOGGER_MOCK_FILE"
	fi
}

# Mock wifi command
wifi() {
	# Just echo to a log file for testing
	if [ -n "$WIFI_MOCK_FILE" ]; then
		echo "wifi $*" >> "$WIFI_MOCK_FILE"
	fi
	return 0
}

# Setup test environment
setup_test_env() {
	TEST_TEMP_DIR="$(mktemp -d)"
	export UCI_MOCK_FILE="$TEST_TEMP_DIR/uci_mock.conf"
	export LOGGER_MOCK_FILE="$TEST_TEMP_DIR/logger.log"
	export WIFI_MOCK_FILE="$TEST_TEMP_DIR/wifi.log"

	# Create empty mock files
	touch "$UCI_MOCK_FILE"
	touch "$LOGGER_MOCK_FILE"
	touch "$WIFI_MOCK_FILE"
}

# Cleanup test environment
cleanup_test_env() {
	if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
		rm -rf "$TEST_TEMP_DIR"
	fi
}

# Set a mock UCI value
mock_uci_set() {
	local key="$1"
	local value="$2"
	echo "${key}=${value}" >> "$UCI_MOCK_FILE"
}

# Get mock logger output
get_logger_output() {
	if [ -f "$LOGGER_MOCK_FILE" ]; then
		cat "$LOGGER_MOCK_FILE"
	fi
}

# Clear mock logger output
clear_logger_output() {
	if [ -f "$LOGGER_MOCK_FILE" ]; then
		> "$LOGGER_MOCK_FILE"
	fi
}
