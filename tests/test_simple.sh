#!/bin/sh
# Simplified practical tests that work without complex mocking

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

echo "=== Practical Validation Tests ==="
echo ""

FAILED=0

# Test 1: Can we source the scripts without errors?
echo "Test: Source util.sh without errors"
if . "$PROJECT_ROOT/files/usr/lib/optwifi/util.sh" 2>/dev/null; then
	echo "  ✓ PASS"
else
	echo "  ✗ FAIL - util.sh has sourcing errors"
	FAILED=1
fi

# Test 2: Can we source core.sh without errors?
echo "Test: Source core.sh without errors"
# core.sh sources util.sh, so we need to make util.sh available at expected path
# or source util.sh first
. "$PROJECT_ROOT/files/usr/lib/optwifi/util.sh" 2>/dev/null
# Now modify core.sh sourcing for test (skip the source line)
if sh -n "$PROJECT_ROOT/files/usr/lib/optwifi/core.sh" 2>/dev/null; then
	echo "  ✓ PASS (syntax valid)"
else
	echo "  ✗ FAIL - core.sh has syntax errors"
	FAILED=1
fi

# Test 3: Function definitions exist
echo "Test: Required functions are defined"
. "$PROJECT_ROOT/files/usr/lib/optwifi/util.sh" 2>/dev/null
# Source core.sh's functions by filtering out the util.sh source line
eval "$(grep -v '^\. /usr/lib/optwifi/util.sh' "$PROJECT_ROOT/files/usr/lib/optwifi/core.sh")" 2>/dev/null

for func in log_info log_debug log_error is_enabled get_ssid_dhcp_option hex_to_ascii validate_ssid update_wireless_ssid process_dhcp_ssid; do
	if command -v "$func" >/dev/null 2>&1 || type "$func" >/dev/null 2>&1; then
		echo "  ✓ Function '$func' is defined"
	else
		echo "  ✗ Function '$func' is NOT defined"
		FAILED=1
	fi
done

# Test 4: validate_ssid logic (direct testing)
echo "Test: validate_ssid logic"
# Already loaded above

# Should accept valid SSID
if validate_ssid "ValidNetwork" 2>/dev/null; then
	echo "  ✓ Accepts valid SSID"
else
	echo "  ✗ Rejects valid SSID"
	FAILED=1
fi

# Should reject empty SSID
if validate_ssid "" 2>/dev/null; then
	echo "  ✗ Accepts empty SSID (should reject)"
	FAILED=1
else
	echo "  ✓ Rejects empty SSID"
fi

# Should reject too-long SSID (>32 bytes)
if validate_ssid "123456789012345678901234567890123" 2>/dev/null; then
	echo "  ✗ Accepts 33-byte SSID (should reject)"
	FAILED=1
else
	echo "  ✓ Rejects SSID >32 bytes"
fi

# Should reject SSID with tab character
if validate_ssid "$(printf "Bad\tSSID")" 2>/dev/null; then
	echo "  ✗ Accepts tab character (should reject)"
	FAILED=1
else
	echo "  ✓ Rejects tab character (control char)"
fi

# Should accept SSID with spaces (spaces are not control chars)
if validate_ssid "My WiFi Network" 2>/dev/null; then
	echo "  ✓ Accepts spaces in SSID"
else
	echo "  ✗ Rejects spaces (should accept)"
	FAILED=1
fi

# Should reject SSID with newline (using literal newline in string)
if validate_ssid "Bad
SSID" 2>/dev/null; then
	echo "  ✗ Accepts newline (should reject)"
	FAILED=1
else
	echo "  ✓ Rejects newline (control char)"
fi

# Test 5: Check DHCP hook script can be sourced
echo "Test: DHCP hook script loads without errors"
if sh -n "$PROJECT_ROOT/files/etc/udhcpc.user.d/50-optwifi" 2>/dev/null; then
	echo "  ✓ DHCP hook has valid syntax"
else
	echo "  ✗ DHCP hook has syntax errors"
	FAILED=1
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
	echo "✓ All practical tests passed"
	exit 0
else
	echo "✗ Some tests failed"
	exit 1
fi
