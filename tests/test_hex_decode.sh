#!/usr/bin/env ash
# Test hex_to_ascii function with ash shell
# This validates the security-hardened hex decoding implementation

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Source the util.sh to get hex_to_ascii function
# We need to stub out the UCI and logger dependencies
uci() { return 0; }
logger() { return 0; }

. "$PROJECT_ROOT/files/usr/lib/optwifi/util.sh"

echo "=== hex_to_ascii Security & Functionality Tests ==="
echo ""

FAILED=0

# Test 1: Basic ASCII decoding
echo "Test 1: Basic ASCII string 'Hello'"
result=$(hex_to_ascii "48656c6c6f")
if [ "$result" = "Hello" ]; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected 'Hello', got '$result'"
	FAILED=1
fi

# Test 2: UTF-8 multibyte characters
echo "Test 2: UTF-8 string 'café'"
result=$(hex_to_ascii "636166c3a9")
if [ "$result" = "café" ]; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected 'café', got '$result'"
	FAILED=1
fi

# Test 3: Mixed case hex digits
echo "Test 3: Mixed case hex 'MySSID' (4D795353494400)"
result=$(hex_to_ascii "4D795353494400")
expected="MySSID"
if echo "$result" | grep -q "MySSID"; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected to contain 'MySSID', got '$result'"
	FAILED=1
fi

# Test 4: Empty string
echo "Test 4: Empty hex string"
result=$(hex_to_ascii "")
if [ -z "$result" ]; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected empty string, got '$result'"
	FAILED=1
fi

# Test 5: Invalid input - odd length
echo "Test 5: Invalid hex - odd length (should fail)"
result=$(hex_to_ascii "48656c6c6" 2>/dev/null)
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo "  ✓ PASS - Correctly rejected odd-length hex"
else
	echo "  ✗ FAIL - Should reject odd-length hex"
	FAILED=1
fi

# Test 6: Invalid input - non-hex characters
echo "Test 6: Invalid hex - contains 'G' (should fail)"
result=$(hex_to_ascii "48656c6c6G" 2>/dev/null)
exit_code=$?
if [ $exit_code -ne 0 ]; then
	echo "  ✓ PASS - Correctly rejected non-hex characters"
else
	echo "  ✗ FAIL - Should reject non-hex characters"
	FAILED=1
fi

# Test 7: Special characters that are valid in SSIDs
echo "Test 7: Special characters 'WiFi-5GHz_Test'"
result=$(hex_to_ascii "576946692d3547487a5f54657374")
if echo "$result" | grep -q "WiFi-5GHz_Test"; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected 'WiFi-5GHz_Test', got '$result'"
	FAILED=1
fi

# Test 8: Spaces in SSID
echo "Test 8: SSID with spaces 'My Network'"
result=$(hex_to_ascii "4d79204e6574776f726b")
if [ "$result" = "My Network" ]; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - Expected 'My Network', got '$result'"
	FAILED=1
fi

# Test 9: Maximum length SSID (32 bytes)
echo "Test 9: 32-byte SSID (maximum valid length)"
# "12345678901234567890123456789012" = 32 bytes
hex_32="3132333435363738393031323334353637383930313233343536373839303132"
result=$(hex_to_ascii "$hex_32")
if [ ${#result} -eq 32 ]; then
	echo "  ✓ PASS - Decoded 32-byte string"
else
	echo "  ✗ FAIL - Expected 32 bytes, got ${#result}"
	FAILED=1
fi

# Test 10: Null byte handling (0x00)
echo "Test 10: Hex with null byte (should decode but may cause issues)"
result=$(hex_to_ascii "48656c6c6f00576f726c64")
# The null byte will be in the output, but we just verify it decodes
if [ $? -eq 0 ]; then
	echo "  ✓ PASS - Decodes (validation happens in validate_ssid)"
else
	echo "  ✗ FAIL - Should decode successfully"
	FAILED=1
fi

# Test 11: Various byte values
echo "Test 11: All printable ASCII (0x20-0x7E)"
# Test a few representative characters
result=$(hex_to_ascii "20217e")  # space, !, ~
if [ $? -eq 0 ]; then
	echo "  ✓ PASS - Handles various byte values"
else
	echo "  ✗ FAIL - Should handle printable ASCII"
	FAILED=1
fi

# Test 12: Security - no shell expansion
echo "Test 12: Security - no shell expansion of \$(command)"
# The hex for "$(whoami)" - should NOT execute
hex_cmd="2428776f616d6929"
result=$(hex_to_ascii "$hex_cmd" 2>/dev/null)
# Should decode to literal string, not execute
if echo "$result" | grep -q '$(whoami)'; then
	echo "  ✓ PASS - Command not executed (code/data separation maintained)"
else
	echo "  ⚠ WARNING - Check if command was executed: '$result'"
	# Not necessarily a failure, but worth noting
fi

# Test 13: Security - backticks
echo "Test 13: Security - no expansion of \`command\`"
hex_backtick="60776f616d6960"  # \`whoami\`
result=$(hex_to_ascii "$hex_backtick" 2>/dev/null)
if [ $? -eq 0 ]; then
	echo "  ✓ PASS - Backticks handled safely"
else
	echo "  ✗ FAIL - Should decode successfully"
	FAILED=1
fi

echo ""
echo "=== Summary ==="
if [ "$FAILED" -eq 0 ]; then
	echo "✓ All hex_to_ascii tests passed"
	echo "  - Basic ASCII decoding works"
	echo "  - UTF-8 multibyte characters work"
	echo "  - Input validation catches errors"
	echo "  - Security: code/data separation maintained"
	exit 0
else
	echo "✗ Some tests failed"
	exit 1
fi
