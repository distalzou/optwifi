# Missing Test Coverage

## UCI Helper Functions (util.sh)

- [ ] uci_get() returns configured value when key exists
- [ ] uci_get() returns default value when key is missing
- [ ] is_enabled() returns true when enabled=1
- [ ] is_enabled() returns false when enabled=0, not set, or invalid value
- [ ] get_ssid_dhcp_option() returns configured option number
- [ ] get_ssid_dhcp_option() returns empty when not configured
- [ ] Log level conversion: debug→3, info→2, error→1, invalid→2

## Core Functions (core.sh)

- [ ] validate_ssid() accepts 1-32 byte SSIDs with spaces
- [ ] validate_ssid() accepts exactly 32-byte SSID
- [ ] validate_ssid() rejects empty SSID
- [ ] validate_ssid() rejects SSID >32 bytes
- [ ] validate_ssid() rejects control characters (tab, newline, etc.)
- [ ] update_wireless_ssid() skips update when SSID already matches
- [ ] update_wireless_ssid() does NOT call wifi reload when SSID unchanged
- [ ] update_wireless_ssid() updates all wireless interfaces
- [ ] process_dhcp_ssid() exits when no option configured
- [ ] process_dhcp_ssid() exits when option not in environment
- [ ] process_dhcp_ssid() decodes hex and updates SSID correctly
- [ ] process_dhcp_ssid() rejects invalid SSIDs

## End-to-End Integration

- [ ] Feature disabled: no action taken, SSID unchanged
- [ ] Full flow: DHCP option → decode → update → wifi reload
- [ ] Multiple DHCP events update SSID sequentially
- [ ] Same SSID received: no wifi reload (optimization)
- [ ] Invalid hex data: SSID unchanged
- [ ] SSID too long: rejected, SSID unchanged
- [ ] Odd-length hex: rejected, SSID unchanged
- [ ] Debug logging produces expected output