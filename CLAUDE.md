# DHCP-Configured WiFi SSID for OpenWrt

## Project Overview
This package enables dynamic WiFi SSID configuration via DHCP options on OpenWrt routers. When the router receives a DHCP response containing a configured option number, it automatically updates the wireless SSID and reloads the WiFi service.

## Current Implementation Status ✅

### Completed Features
- ✅ **Modular architecture** - Clean separation: util.sh, core.sh, DHCP hook
- ✅ **UCI configuration** - `/etc/config/optwifi` with safe defaults (disabled by default)
- ✅ **Configurable DHCP option** - User sets `ssid_dhcp_option` via UCI
- ✅ **Error handling** - Comprehensive validation and logging throughout
- ✅ **SSID validation** - Length checks (0-32 bytes per 802.11 spec)
- ✅ **Smart updates** - Only reloads WiFi if SSID actually changes (performance optimization)
- ✅ **Logging levels** - error/info/debug with proper hierarchy
- ✅ **OpenWrt package** - Complete Makefile for building .ipk files
- ✅ **Documentation** - README.md with examples and troubleshooting
- ✅ **Test suite** - Automated syntax and functional validation

### Architecture

```
optwifi/
├── Makefile                                    # OpenWrt package build
├── README.md                                   # User documentation
├── CLAUDE.md                                   # This file - project context
├── files/                                      # Files to install
│   ├── etc/
│   │   ├── config/
│   │   │   └── optwifi                        # UCI config (disabled by default)
│   │   └── udhcpc.user.d/
│   │       └── 50-optwifi                     # DHCP hook (entry point)
│   ├── usr/bin/
│   │   └── optwifi-configure                  # Helper script for easy setup
│   └── usr/lib/optwifi/
│       ├── util.sh                            # Logging, UCI helpers, hex decoding
│       └── core.sh                            # SSID validation, update logic
├── tests/                                      # Test suite
│   ├── test_runner.sh                         # Main test orchestrator
│   ├── test_syntax.sh                         # Syntax validation
│   ├── test_simple.sh                         # Functional tests
│   ├── mocks/
│   │   └── test_helpers.sh                    # Test utilities
│   └── README.md                              # Test documentation
└── current/                                    # Original proof-of-concept
    └── etc/udhcpc.user                        # Initial working implementation
```

## Running Tests

```bash
# Run all tests
sh tests/test_runner.sh

# Tests validate:
# - Shell script syntax
# - Function definitions
# - SSID validation logic
# - Code quality checks
```

All tests currently pass ✅

## Configuration Example

```bash
# Enable the feature
uci set optwifi.settings.enabled=1

# Configure which DHCP option contains the SSID (240 is an example)
uci set optwifi.settings.ssid_dhcp_option=240

# Optional: Enable debug logging
uci set optwifi.settings.log_level=debug

# Commit changes
uci commit optwifi

# Quick method - use helper script
optwifi-configure enable-ssid 240 lan
/etc/init.d/network restart

# OR manual method - configure network interface to request the DHCP option
uci set network.lan.reqopts='240'
uci commit network
/etc/init.d/network restart
```

## Key Design Decisions

### Security & Data Handling
- **Disabled by default** - Explicit user configuration required
- **Code/data separation principle** - Network data never evaluated by shell
- **Input validation** - SSID length, format checking
- **TODO**: Enhanced hex decoding security (planned next step)

### Performance Optimizations
- **UCI called efficiently** - Config loaded once per DHCP event
- **Smart WiFi reloads** - Only when SSID actually changes
- **Single UCI query** - Parses `uci show wireless` once to check all SSIDs

### Naming Conventions (Future-Ready)
- Config options: `ssid_dhcp_option`, `password_dhcp_option`, etc.
- Functions: `get_ssid_dhcp_option()`, `process_dhcp_ssid()`, etc.
- Clear pattern for adding new DHCP-configurable parameters

## Remaining Work

### ~~High Priority - Security Hardening~~ ✅ COMPLETED
- ✅ **Secure hex decoding** - Pure POSIX implementation using temp files
  - Maintains strict code/data separation (no shell expansion of network data)
  - Prevents shell injection attacks
  - Handles UTF-8/international characters correctly
  - Validates hex format (even length, valid hex digits only)
- ✅ **Control character validation** - Rejects 0x00-0x1F, 0x7F in SSIDs
  - Prevents issues with UCI, logging, and display
  - Uses grep [:cntrl:] class (no external dependencies like od/hexdump)
  - Compatible with minimal busybox installations
- ✅ **Malformed data handling** - Graceful failures for invalid hex
  - Validates hex string format before processing
  - Proper error logging on decode failures

### Future Enhancements
- **WPA password configuration** via separate DHCP option
- **Multiple wireless parameters** (channel, encryption mode, etc.)
- **Per-interface control** - Whitelist/blacklist which radios to update
- **Enhanced testing** - Integration tests with full mocking
- **Debouncing** - Handle rapid DHCP renewals gracefully

## Technical Constraints
- Target platform: OpenWrt (ash shell, UCI config system)
- No compilation needed (shell scripts only)
- Must work with udhcpc DHCP client
- Should integrate cleanly with UCI and /etc/config/wireless
- POSIX shell compatible (no bash-isms)

## Success Criteria ✅

Quality software that provides real value without overengineering:
- ✅ Works reliably in real-world scenarios
- ✅ Easy to install and configure
- ✅ Well-documented for users
- ✅ Follows OpenWrt community standards
- ✅ Maintainable code structure
- ✅ Automated testing

## Development Workflow

1. **Make changes** to code in `files/`
2. **Run tests** - `sh tests/test_runner.sh`
3. **Review** - Code review focusing on shell best practices
4. **Test manually** - On actual OpenWrt device if available
5. **Build package** - `make package/optwifi/compile` (when in buildroot)

## Notes
- Using DHCP option numbers in "private use" range (224-254)
- Option 240 used in examples (user can choose any private range option)
- Initial target: personal use and community package repository
- Code reviewed for shell best practices (quoting, error handling, etc.)
