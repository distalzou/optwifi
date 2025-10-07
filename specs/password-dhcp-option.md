# Implementation Spec: Global Password Configuration via DHCP Options

## Overview

This specification describes the implementation of WPA password configuration via DHCP options for optwifi. This feature complements the existing SSID configuration to enable fully automated WiFi setup across multiple sites.

### Motivation

The current SSID-only implementation is insufficient for real-world deployments because different sites typically have different SSIDs with different passwords. By adding password configuration via DHCP options, we enable:

- Stock of pre-configured APs that work at any site
- Zero per-site configuration required
- Both SSID and password delivered via DHCP
- Only prerequisite: MAC address registration in site's DHCP server

### Design Principles

- **Follow established patterns**: Mirror the existing SSID implementation exactly
- **Security by default**: Disabled unless explicitly configured
- **Performance optimization**: Only reload WiFi when password actually changes
- **Consistent code style**: Reuse patterns from `update_wireless_ssid()`
- **No password logging**: Sensitive values never written to logs

## Implementation Components

### 1. UCI Configuration

**File**: `/etc/config/optwifi`

Add new option to existing config section:

```
config optwifi 'settings'
    option enabled '0'
    option log_level 'info'
    # option ssid_dhcp_option '240'
    # option password_dhcp_option '241'
```

**Changes**:
- Add commented `password_dhcp_option` line
- Remains disabled by default
- User explicitly enables via `optwifi-configure` helper

### 2. Utility Functions

**File**: `/usr/lib/optwifi/util.sh`

Add new function following the same pattern as `get_ssid_dhcp_option()`:

```sh
# Get configured DHCP option number for password
get_password_dhcp_option() {
    uci_get optwifi.settings.password_dhcp_option ""
}
```

**Note**: Reuse existing `hex_to_ascii()` function - no changes needed. It already provides secure hex decoding with code/data separation.

### 3. Core Logic

**File**: `/usr/lib/optwifi/core.sh`

#### 3.1 Password Validation Function

Add `validate_password()` following the same pattern as `validate_ssid()`.

**Validation Rules**:
- Length: 8-63 characters (WPA2/WPA3 specification)
- No control characters (0x00-0x1F, 0x7F)
- Not empty
- Same validation approach as SSID (using [:cntrl:] pattern)

**Note**: Password value is NOT logged (only length), unlike SSID which logs the actual value.

#### 3.2 Update Wireless Password Function

Add `update_wireless_password()` **mirroring the exact pattern from `update_wireless_ssid()`**:

```sh
# Update all wireless passwords
# Input: new password value
# Output: 0 on success, 1 on failure
```

**Key Implementation Details**:
- Model after **while loop pattern** as in `update_wireless_ssid()`
- Parse `uci show wireless | grep '\.key='` output once
- Extract UCI paths and current values
- Build list of paths needing updates
- Only update if password actually differs (performance optimization)
- Only reload WiFi if updates were made
- Log actions but **never log the password value** (security)

#### 3.3 Process DHCP Password Function

Add `process_dhcp_password()` following the same pattern as `process_dhcp_ssid()`.

**Note**: This function intentionally does NOT log the decoded password value or the hex representation. Only logs that a password was received and decoded.

### 4. DHCP Hook

**File**: `/etc/udhcpc.user.d/50-optwifi`

Update to call both SSID and password processing.

**Performance Note**: If both SSID and password are received in the same DHCP response and both change, WiFi will be reloaded twice (once per function).

This is fine for this initial implementation but it should be the focus of future work to optimize it so that we only reload WiFi once per recevied DHCP message.

### 5. Configuration Helper

**File**: `/usr/bin/optwifi-configure`

#### 5.1 Update Usage Text

Include new options.

#### 5.2 Update Status Function

Report settings for new options also.

#### 5.3 Add enable_password Function

To enable this feature

**Key Detail**: The function appends to existing `reqopts` if already set, allowing both SSID and password options to be requested.

#### 5.4 Update Command Handler

Make it recognize and implement the new command.

### 6. Testing

**File**: `tests/test_simple.sh` (to be extended)

Add new test functions:
- test_validate_password()

## Security Considerations

### Password Handling

1. **No password logging**: Password values are never written to logs
   - Only log "password updated" or "password validation failed"
   - Only log password length during validation (debug level)

2. **Same secure hex decoding**: Reuses `hex_to_ascii()` with temp file approach
   - Maintains strict code/data separation
   - No shell expansion of network data
   - Prevents injection attacks

3. **WPA password validation**:
   - Enforces 8-63 character length (WPA2/WPA3 spec)
   - Rejects control characters
   - Same validation approach as SSID

4. **Disabled by default**: Requires explicit user configuration

### Performance Optimization

- Smart updates: only reload WiFi if password actually changes
- Single UCI query: `uci show wireless | grep '\.key='` called once
- Same pattern as SSID for consistency and maintainability

## Documentation Updates

### README.md

Add password configuration section:

### Manual Configuration

Update to include password setting.

### Configure your DHCP server

Update to show setting multiple options on the DHCP server

### CLAUDE.md

Update implementation status:

```markdown
## Current Implementation Status ✅

### Completed Features
- ✅ **Modular architecture** - Clean separation: util.sh, core.sh, DHCP hook
- ✅ **UCI configuration** - `/etc/config/optwifi` with safe defaults (disabled by default)
- ✅ **Configurable DHCP options** - User sets option numbers via UCI
- ✅ **SSID configuration** - Global SSID via DHCP option
- ✅ **Password configuration** - Global WPA password via DHCP option
- ✅ **Error handling** - Comprehensive validation and logging throughout
- ✅ **Validation** - SSID length (0-32 bytes), password length (8-63 chars)
- ✅ **Smart updates** - Only reloads WiFi if values actually change
- ✅ **Logging levels** - error/info/debug with proper hierarchy
- ✅ **OpenWrt package** - Standalone build script for .ipk files
- ✅ **Documentation** - README.md with examples and troubleshooting
- ✅ **Test suite** - Automated syntax and functional validation
```

### DHCP-OPTIONS-DESIGN.md

Update implementation status section:

```markdown
## Implementation Status

- ✅ **Global SSID** - Fully implemented (`optwifi-configure enable-ssid`)
- ✅ **Global password** - Fully implemented (`optwifi-configure enable-password`)
- ⬜ **Per-radio overrides** - Planned (`optwifi-configure enable-overrides`)
- ⬜ **Channel config** - Planned (`optwifi-configure enable-channels`)
```

## Example Usage Scenarios

### Scenario 1: Enable Both SSID and Password

```bash
# Configure optwifi
optwifi-configure enable-ssid 240 lan
optwifi-configure enable-password 241 lan
/etc/init.d/network restart

# DHCP server sends both options
# Result: All radios get same SSID and password
```

### Scenario 2: SSID Only (Existing Behavior)

```bash
# Configure only SSID
optwifi-configure enable-ssid 240 lan
/etc/init.d/network restart

# Password remains unchanged from UCI config
```

### Scenario 3: Check Current Status

```bash
optwifi-configure status

# Output shows:
# - Enabled: 0 or 1
# - SSID DHCP Option: 240 (or not set)
# - Password DHCP Option: 241 (or not set)
# - Network interface reqopts
```

## Implementation Checklist

- [ ] Add `password_dhcp_option` to `/etc/config/optwifi`
- [ ] Add `get_password_dhcp_option()` to `util.sh`
- [ ] Add `validate_password()` to `core.sh`
- [ ] Add `update_wireless_password()` to `core.sh` (mirror SSID pattern)
- [ ] Add `process_dhcp_password()` to `core.sh`
- [ ] Update DHCP hook to call `process_dhcp_password()`
- [ ] Add `enable_password` command to `optwifi-configure`
- [ ] Update `show_usage()` in `optwifi-configure`
- [ ] Update `show_status()` in `optwifi-configure`
- [ ] Add password validation tests to test suite
- [ ] Update README.md with password configuration
- [ ] Update CLAUDE.md implementation status
- [ ] Update DHCP-OPTIONS-DESIGN.md implementation status
- [ ] Test on actual OpenWrt device

## Future Considerations

### WiFi Reload Optimization

Currently, if both SSID and password are received in the same DHCP response and both change, WiFi will be reloaded twice. Future optimization could:

1. Track reload state: add a "reload needed" flag
2. Each update function sets the flag instead of reloading immediately
3. DHCP hook checks flag at end and reloads once if needed

This optimization is deferred because:
- Current approach is simpler and more maintainable
- DHCP updates are infrequent events
- Double reload is not a significant issue in practice
- Can be added later without breaking changes

### Password Strength Validation

The current implementation validates WPA technical requirements (8-63 characters, no control characters) but does not check password strength. Future enhancement could add optional password strength checking:

- Warn if password is too simple
- Check for common passwords
- Configurable via UCI option

This is deferred because:
- Not required for basic functionality
- Password strength is DHCP server administrator's responsibility
- Can be added as optional feature later

## References

- WPA2/WPA3 password requirements: 8-63 ASCII characters
- OpenWrt UCI documentation: https://openwrt.org/docs/guide-user/base-system/uci
- Existing SSID implementation: [files/usr/lib/optwifi/core.sh](../files/usr/lib/optwifi/core.sh)
- DHCP options design: [DHCP-OPTIONS-DESIGN.md](../DHCP-OPTIONS-DESIGN.md)
