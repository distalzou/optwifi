#!/bin/sh
# Verify that \x hex escapes work in the current shell
# This is critical for the hex_to_ascii implementation

echo "=== Verifying hex escape support ==="
echo ""

SHELL_NAME=$(basename "$0")
if command -v ash >/dev/null 2>&1; then
	echo "Testing with: ash (OpenWrt default)"
	TEST_SHELL="ash"
else
	echo "Testing with: sh"
	TEST_SHELL="sh"
fi

echo ""
echo "Test 1: Direct hex escape \\x45 (should produce 'E')"
result=$($TEST_SHELL -c 'printf "\x45"')
if [ "$result" = "E" ]; then
	echo "✓ PASS: hex escape works correctly"
else
	echo "✗ FAIL: got '$result' instead of 'E'"
	echo "  Hex dump:"
	printf "%s" "$result" | od -An -tx1
fi

echo ""
echo "Test 2: Variable hex escape \\x\${hex}"
result=$($TEST_SHELL -c 'hex="4d"; printf "\\x${hex}"')
expected=$(printf "\x4d")
if [ "$result" = "$expected" ]; then
	echo "✓ PASS: variable hex escape works"
else
	echo "✗ FAIL: variable hex escape produced wrong output"
	echo "  Expected (0x4d = 'M'):"
	printf "\x4d" | od -An -tx1
	echo "  Got:"
	printf "%s" "$result" | od -An -tx1
fi

echo ""
echo "Test 3: Full hex decoding (MySSID)"
result=$($TEST_SHELL <<'SCRIPT'
hex="4d795353494400"
tmpfile=$(mktemp)
pos=1
len=${#hex}
while [ $pos -le $len ]; do
	byte=$(echo "$hex" | cut -c${pos}-$((pos+1)))
	printf "\\x${byte}" >> "$tmpfile"
	pos=$((pos+2))
done
cat "$tmpfile"
rm -f "$tmpfile"
SCRIPT
)

if [ "$result" = "MySSID" ]; then
	echo "✓ PASS: full hex decoding works"
else
	echo "✗ FAIL: full hex decoding failed"
	echo "  Expected: MySSID"
	echo "  Got: $result"
fi

echo ""
echo "=== Verification complete ==="
