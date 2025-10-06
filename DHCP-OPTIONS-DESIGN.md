# DHCP Option Numbering for WiFi Configuration

## Overview

This document defines how optwifi uses DHCP options to configure WiFi parameters. The design balances simplicity for common use cases with extensibility for advanced configurations.

**The key trade-off:** We use slightly more complex syntax within some DHCP option values (simple key-value encoding) to conserve DHCP option numbers—a limited resource with only 31 available in the private-use range (224-254). This allows us to support comprehensive WiFi configuration with just 4-5 option numbers while keeping simple deployments trivial.

## Design Approach: Global + Per-Radio Overrides

Combine global options (for simple cases) with structured override options (for advanced cases) using plain-text encoding that's easy to configure in DHCP servers and safe to parse in POSIX shell.

### Supported Parameters

optwifi supports multiple WiFi parameters via DHCP options. **Option numbers are not hardcoded** - administrators configure them using the `optwifi-configure` command.

| Parameter | Purpose | Format | Max Size | `optwifi-configure` command |
|-----------|---------|--------|----------|----------------------------|
| **SSID** | Global SSID | Plain text | 32 bytes | `enable-ssid <option> <interface>` |
| **Password** | Global WPA password | Plain text | 63 chars | `enable-password <option> <interface>` (planned) |
| **Per-radio overrides** | SSID/password per radio | `radioN\|key=value;...` | 255 bytes | `enable-overrides <option> <interface>` (planned) |
| **Channel config** | Frequency/channel per radio | `radioN\|key=value;...` | 255 bytes | `enable-channels <option> <interface>` (planned) |

**Note:** Option numbers shown in examples below (240-243) are for illustration only. Your deployment may use different numbers.

## Configuration Examples

### Example 1: Simple Deployment (Most Common)
Single SSID and password across all radios.

**OpenWrt setup:**
```bash
# Use option 240 for SSID (you could use any number 224-254)
optwifi-configure enable-ssid 240 lan
/etc/init.d/network restart

# Future: enable password
# optwifi-configure enable-password 241 lan
```

**DHCP server config:**
```
option custom-ssid code 240 = text;
option custom-password code 241 = text;

host ap01 {
    hardware ethernet aa:bb:cc:dd:ee:ff;
    option custom-ssid "CoffeeShop-WiFi";
    option custom-password "espresso123";
}
```

**Result:** All radios broadcast "CoffeeShop-WiFi" with password "espresso123"

### Example 2: Per-Radio SSIDs
Different SSID for 2.4GHz and 5GHz radios.

**OpenWrt setup:**
```bash
optwifi-configure enable-ssid 240 lan
# optwifi-configure enable-password 241 lan         # planned
# optwifi-configure enable-overrides 242 lan        # planned
/etc/init.d/network restart
```

**DHCP server config:**
```
option custom-ssid code 240 = text;
option custom-password code 241 = text;
option custom-overrides code 242 = text;

host ap02 {
    hardware ethernet aa:bb:cc:dd:ee:ff;
    option custom-ssid "HomeNet";  # Fallback for radios not in overrides
    option custom-password "defaultpass";
    option custom-overrides "radio0|ssid=HomeNet-2G;radio1|ssid=HomeNet-5G";
}
```

**Result:**
- radio0 (2.4GHz): SSID="HomeNet-2G", password="defaultpass" (SSID from override, password from global)
- radio1 (5GHz): SSID="HomeNet-5G", password="defaultpass" (SSID from override, password from global)

### Example 3: Full Per-Radio Customization
Different SSID, password, and channel per radio.

**OpenWrt setup:**
```bash
optwifi-configure enable-ssid 240 lan
# optwifi-configure enable-overrides 242 lan        # planned
# optwifi-configure enable-channels 243 lan         # planned
/etc/init.d/network restart
```

**DHCP server config:**
```
option custom-ssid code 240 = text;
option custom-overrides code 242 = text;
option custom-channels code 243 = text;

host ap03 {
    hardware ethernet aa:bb:cc:dd:ee:ff;
    option custom-ssid "Fallback";  # Used if radio not specified in overrides
    option custom-overrides "radio0|ssid=IoT-Network|psk=iot123;radio1|ssid=MainNetwork|psk=secure456";
    option custom-channels "radio0|channel=1|htmode=HT20;radio1|channel=36|htmode=VHT80";
}
```

**Result:**
- radio0: SSID="IoT-Network", password="iot123", channel 1, 20MHz width
- radio1: SSID="MainNetwork", password="secure456", channel 36, 80MHz width

## Structured Format Specification

The per-radio override and channel configuration parameters use this encoding format:

```
radioN|key1=value1|key2=value2;radioM|key3=value3
```

### Grammar
- Radio blocks separated by semicolon (`;`)
- Each block starts with radio identifier (`radio0`, `radio1`, etc.)
- Pipe character (`|`) separates radio ID from first setting and between settings
- Settings are `key=value` pairs
- No nesting or escaping supported

### Character Restrictions
- Semicolon (`;`) and pipe (`|`) are reserved delimiters—cannot appear in values
- Equals (`=`) separates keys from values—cannot appear in keys or values
- SSIDs and passwords should not contain these characters (validated during parsing)
- Control characters (0x00-0x1F, 0x7F) are rejected

### Precedence Rules
- Per-radio overrides take precedence over global defaults for the same parameter
- Example: If global SSID is "Default" and per-radio override sets `radio0|ssid=Custom`, then radio0 gets "Custom" and other radios get "Default"
- Specifying non-existent radios (e.g., `radio5` on a 2-radio device) generates warnings but doesn't affect other radios

### Parsing Algorithm
1. Split on `;` to get per-radio blocks
2. For each block, split on first `|` to separate radio ID from settings
3. Split remaining settings on `|` to get individual `key=value` pairs
4. Split each pair on `=` to get key and value
5. Validate: radio ID format, key names, value constraints

### Size Efficiency
- Typical example: `radio0|ssid=Home-2G|psk=pass1;radio1|ssid=Home-5G|psk=pass2` = 67 bytes
- Supports 4-6 radios with typical settings within 255-byte DHCP option limit

## Implementation Status

- ✅ **Global SSID** - Fully implemented (`optwifi-configure enable-ssid`)
- ⬜ **Global password** - Planned (`optwifi-configure enable-password`)
- ⬜ **Per-radio overrides** - Planned (`optwifi-configure enable-overrides`)
- ⬜ **Channel config** - Planned (`optwifi-configure enable-channels`)

## Future Extensions

### Potential Future Parameters
Each would be enabled via a new `optwifi-configure` command with user-specified option numbers:

- **MAC address filtering** - `enable-mac-filter <option> <interface>`
- **Guest network configuration** - `enable-guest-network <option> <interface>`
- **VLAN assignments per SSID** - `enable-vlan-map <option> <interface>`
- **Advanced encryption settings** (WPA3, etc.) - `enable-encryption <option> <interface>`
- **Bandwidth/QoS limits** - `enable-qos <option> <interface>`
- **Captive portal settings** - `enable-captive-portal <option> <interface>`

### Guidelines for New Parameters
1. **Evaluate if it fits in existing structured options first** - Can it be added to overrides/channels format?
2. **Consider usage frequency** - Common settings may deserve dedicated simple options
3. **Group related settings** - Don't create separate options for tiny parameters
4. **Design the `optwifi-configure` command** - Clear naming, proper validation
5. **Document thoroughly** - Update this file with format specification and rationale

## Design Rationale

### Why This Approach?

The DHCP private-use range (224-254) provides only 31 option numbers. Simple approaches like "one option per parameter" would quickly exhaust this space:
- One SSID per radio: 6 options for a 3-radio device
- Add passwords: 12 options
- Add channels: 18 options
- No room left for future features

Complex approaches like JSON encoding introduce security risks and parsing complexity in POSIX shell.
