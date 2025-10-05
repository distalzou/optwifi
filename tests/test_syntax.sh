#!/bin/sh
# Syntax validation tests
# Checks all shell scripts for syntax errors

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
FAILED=0

echo "=== Syntax Validation ==="
echo ""

# Find all shell scripts
SCRIPTS="
$PROJECT_ROOT/files/etc/udhcpc.user.d/50-optwifi
$PROJECT_ROOT/files/usr/lib/optwifi/util.sh
$PROJECT_ROOT/files/usr/lib/optwifi/core.sh
$PROJECT_ROOT/files/usr/bin/optwifi-configure
"

SH="ash"

# Check each script
for script in $SCRIPTS; do
	if [ ! -f "$script" ]; then
		echo "✗ SKIP: $script (not found)"
		continue
	fi

	printf "Checking %s ... " "$(basename "$script")"

	# Check syntax
	if $SH -n "$script" 2>/dev/null; then
		echo "✓ OK"
	else
		echo "✗ SYNTAX ERROR"
		sh -n "$script"
		FAILED=1
	fi
done

echo ""

# Check for common issues
echo "=== Additional Checks ==="
echo ""

for script in $SCRIPTS; do
	if [ ! -f "$script" ]; then
		continue
	fi

	script_name="$(basename "$script")"

	# Check for correct shebang
	if head -n 1 "$script" | grep -q '^#!/bin/sh' || head -n 1 "$script" | grep -q '^#!/usr/bin/env sh'; then
		echo "✓ $script_name has correct shebang"
	else
		echo "✗ $script_name has missing or incorrect shebang"
		FAILED=1
	fi

	# Check for unquoted variables in dangerous contexts (basic check)
	# This is a simple heuristic - not perfect but catches common issues
	if grep -n '\[ *\$[A-Za-z_][A-Za-z0-9_]* *[=!<>]' "$script" | grep -v '"' | grep -v "'" >/dev/null 2>&1; then
		echo "⚠ $script_name may have unquoted variables in test expressions"
		grep -n '\[ *\$[A-Za-z_][A-Za-z0-9_]* *[=!<>]' "$script" | grep -v '"' | grep -v "'" | head -3
		# Not failing on this, just warning
	fi
done

echo ""

if [ "$FAILED" -eq 0 ]; then
	echo "✓ All syntax checks passed"
	exit 0
else
	echo "✗ Some syntax checks failed"
	exit 1
fi
