#!/bin/sh
# optwifi test runner
# Runs all tests and reports results

set -e

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
	GREEN='\033[0;32m'
	RED='\033[0;31m'
	YELLOW='\033[1;33m'
	NC='\033[0m' # No Color
else
	GREEN=''
	RED=''
	YELLOW=''
	NC=''
fi

TESTS_PASSED=0
TESTS_FAILED=0
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run a test script
run_test() {
	local test_script="$1"
	local test_name="$(basename "$test_script" .sh)"
	local shell="${2:-sh}"

	printf "${YELLOW}Running ${test_name}...${NC}\n"

	if "$shell" "$test_script"; then
		printf "${GREEN}✓ ${test_name} PASSED${NC}\n\n"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		printf "${RED}✗ ${test_name} FAILED${NC}\n\n"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

# Detect which shell to use (prefer ash if available, like OpenWrt)
if command -v ash >/dev/null 2>&1; then
	TEST_SHELL="ash"
	SHELL_INFO="ash (OpenWrt-compatible)"
else
	TEST_SHELL="sh"
	SHELL_INFO="sh (ash not available)"
fi

# Main test execution
echo "========================================="
echo "optwifi Test Suite"
echo "========================================="
echo "Test shell: $SHELL_INFO"
echo ""

# Run tests in order
run_test "$TEST_DIR/test_syntax.sh" "$TEST_SHELL"
run_test "$TEST_DIR/test_simple.sh" "$TEST_SHELL"

# Hex decoding tests require ash for printf \x hex escapes
if [ "$TEST_SHELL" = "ash" ]; then
	run_test "$TEST_DIR/test_hex_decode.sh" ash
else
	echo "⚠ Skipping test_hex_decode (requires ash for hex_to_ascii function)"
fi

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
printf "Passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
printf "Failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
	printf "${GREEN}All tests passed!${NC}\n"
	exit 0
else
	printf "${RED}Some tests failed!${NC}\n"
	exit 1
fi
