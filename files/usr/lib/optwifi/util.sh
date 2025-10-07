#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# optwifi utility functions

# UCI helper - get value with default
uci_get() {
	local value
	value=$(uci -q get "$1")
	echo "${value:-$2}"
}

# Load log level once at startup
OPTWIFI_LOG_LEVEL=$(uci_get optwifi.settings.log_level "info")

# Convert log level to numeric value for comparison
case "$OPTWIFI_LOG_LEVEL" in
	debug) OPTWIFI_LOG_LEVEL_N=3 ;;
	info) OPTWIFI_LOG_LEVEL_N=2 ;;
	error) OPTWIFI_LOG_LEVEL_N=1 ;;
	*) OPTWIFI_LOG_LEVEL_N=2 ;;  # default to info
esac

# Logging functions
log_info() {
	[ "$OPTWIFI_LOG_LEVEL_N" -ge 2 ] && logger -t optwifi -p user.info "$@"
}

log_debug() {
	[ "$OPTWIFI_LOG_LEVEL_N" -ge 3 ] && logger -t optwifi -p user.debug "$@"
}

log_error() {
	logger -t optwifi -p user.err "$@"
}

# Check if feature is enabled
is_enabled() {
	local enabled
	enabled=$(uci_get optwifi.settings.enabled "0")
	[ "$enabled" = "1" ]
}

# Get configured DHCP option number for SSID
get_ssid_dhcp_option() {
	uci_get optwifi.settings.ssid_dhcp_option ""
}

# Get configured DHCP option number for password
get_password_dhcp_option() {
	uci_get optwifi.settings.password_dhcp_option ""
}

# Decode hex string to ASCII
# Input: hex string like "4d795353494400"
# Output: decoded string
# Security: Uses temp file for strict code/data separation
hex_to_ascii() {
	local hex="$1"
	local tmpfile

	# Validate input is hex
	if ! echo "$hex" | grep -qE '^[0-9A-Fa-f]*$'; then
		log_error "Invalid hex string: contains non-hex characters"
		return 1
	fi

	# Check for odd length
	local len=${#hex}
	if [ $((len % 2)) -ne 0 ]; then
		log_error "Invalid hex string: odd number of characters"
		return 1
	fi

	# Create temp file for decoded output
	tmpfile=$(mktemp) || {
		log_error "Failed to create temp file for hex decoding"
		return 1
	}

	# Process byte-by-byte
	# Note: Using \x hex escapes which work in busybox ash (OpenWrt default shell)
	# This is simpler than octal conversion and works on target platform
	local pos=1
	while [ $pos -le $len ]; do
		# Extract two hex characters (one byte)
		local byte=$(echo "$hex" | cut -c${pos}-$((pos+1)))

		# Validate it's valid hex
		if ! echo "$byte" | grep -qE '^[0-9A-Fa-f]{2}$'; then
			log_error "Failed to decode hex byte: $byte"
			rm -f "$tmpfile"
			return 1
		fi

		# Write byte to temp file using hex escape
		# This maintains strict code/data separation
		printf "\\x${byte}" >> "$tmpfile"

		pos=$((pos+2))
	done

	# Read decoded result from file (safe - no shell expansion)
	cat "$tmpfile"
	rm -f "$tmpfile"
}
