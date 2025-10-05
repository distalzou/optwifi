#!/bin/sh
# optwifi core functionality

# Source utilities
. /usr/lib/optwifi/util.sh

# Validate SSID
# Input: SSID string
# Output: 0 if valid, 1 if invalid
validate_ssid() {
	local ssid="$1"
	local len

	# Check if empty
	if [ -z "$ssid" ]; then
		log_error "SSID validation failed: empty SSID"
		return 1
	fi

	# Check length (max 32 bytes per 802.11 spec)
	len=${#ssid}
	if [ "$len" -gt 32 ]; then
		log_error "SSID validation failed: length $len exceeds 32 bytes"
		return 1
	fi

	# Check for control characters (0x00-0x1F, 0x7F)
	# These can cause issues with UCI, logging, and display
	# Using case pattern matching to detect control chars (including embedded newlines)
	# This works in pure POSIX shell without external dependencies
	case "$ssid" in
		*[[:cntrl:]]*)
			log_error "SSID validation failed: contains control characters"
			return 1
			;;
	esac

	log_debug "SSID validation passed: '$ssid' ($len bytes)"
	return 0
}

# Update all wireless SSIDs
# Input: new SSID value
# Output: 0 on success, 1 on failure
update_wireless_ssid() {
	local new_ssid="$1"
	local line ssid_path current_ssid
	local paths_to_update=""

	# Validate SSID first
	if ! validate_ssid "$new_ssid"; then
		return 1
	fi

	log_debug "Checking if SSID update needed: $new_ssid"

	# Parse 'uci show wireless' output once - lines like: wireless.@wifi-iface[0].ssid='CurrentSSID'
	while IFS= read -r line; do
		# Extract path and value from lines like "path='value'"
		ssid_path="${line%%=*}"
		current_ssid="${line#*=}"
		# Remove quotes from value
		current_ssid="${current_ssid#\'}"
		current_ssid="${current_ssid%\'}"

		if [ "$current_ssid" != "$new_ssid" ]; then
			log_debug "$ssid_path needs update: '$current_ssid' -> '$new_ssid'"
			paths_to_update="$paths_to_update $ssid_path"
		else
			log_debug "$ssid_path already set to '$new_ssid'"
		fi
	done <<EOF
$(uci show wireless | grep '\.ssid=')
EOF

	# If nothing needs updating, we're done
	if [ -z "$paths_to_update" ]; then
		log_info "All SSIDs already set to '$new_ssid', no update needed"
		return 0
	fi

	log_info "Updating wireless SSID to: $new_ssid"

	# Update only the paths that need it
	for ssid_path in $paths_to_update; do
		if uci set "$ssid_path=$new_ssid"; then
			log_debug "Set $ssid_path to $new_ssid"
		else
			log_error "Failed to set $ssid_path"
			return 1
		fi
	done

	# Commit changes
	if ! uci commit wireless; then
		log_error "Failed to commit wireless configuration"
		return 1
	fi

	log_info "Successfully updated SSID(s), reloading WiFi"

	# Reload WiFi
	if ! wifi reload; then
		log_error "WiFi reload failed"
		return 1
	fi

	log_info "WiFi reload completed successfully"
	return 0
}

# Process DHCP option for SSID
# Called from DHCP hook with environment variables
process_dhcp_ssid() {
	local opt_num opt_value decoded_ssid

	# Get configured option number for SSID
	opt_num=$(get_ssid_dhcp_option)

	# If no option configured, exit silently
	if [ -z "$opt_num" ]; then
		log_debug "No DHCP option configured, skipping"
		return 0
	fi

	# Build variable name like "opt240"
	local var_name="opt${opt_num}"

	# Get value from environment (indirect reference via eval)
	eval "opt_value=\$$var_name"

	# If option not present in DHCP response, exit silently
	if [ -z "$opt_value" ]; then
		log_debug "DHCP option $opt_num not present in response"
		return 0
	fi

	log_debug "Received DHCP option $opt_num: $opt_value"

	# Decode hex to ASCII
	decoded_ssid=$(hex_to_ascii "$opt_value")

	if [ -z "$decoded_ssid" ]; then
		log_error "Failed to decode hex value: $opt_value"
		return 1
	fi

	log_info "Decoded SSID from DHCP option $opt_num: $decoded_ssid"

	# Update wireless configuration
	update_wireless_ssid "$decoded_ssid"
}
