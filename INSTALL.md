# Installation Guide

## Building the Package

### Prerequisites
- POSIX-compatible shell (sh, bash, ash, etc.)
- Standard utilities: `tar`, `mktemp`, `du` (available on all Linux systems)

### Build Steps

1. **Run the build script:**
   ```bash
   ./build-package.sh
   ```

2. **The script will:**
   - Run all tests to ensure code quality
   - Create package structure
   - Generate control files and install scripts
   - Create the `.ipk` package

3. **Output:**
   - Package file: `build/optwifi_1.0.0-1_all.ipk`
   - Size: ~5-8 KB

## Installing on OpenWrt

### Method 1: Manual Copy and Install

1. **Copy package to router:**
   ```bash
   scp build/optwifi_1.0.0-1_all.ipk root@192.168.1.1:/tmp/
   ```

2. **SSH into router and install:**
   ```bash
   ssh root@192.168.1.1
   opkg install /tmp/optwifi_1.0.0-1_all.ipk
   ```

### Method 2: One-Line Install

```bash
scp build/optwifi_1.0.0-1_all.ipk root@192.168.1.1:/tmp/ && \
ssh root@192.168.1.1 'opkg install /tmp/optwifi_1.0.0-1_all.ipk'
```

## Post-Installation Configuration

After installation, you'll see:

```
optwifi installed successfully!

Quick setup:
  optwifi-configure enable-ssid 240 lan
  /etc/init.d/network restart

For help: optwifi-configure help
```

### Quick Setup Example

```bash
# Enable SSID configuration via DHCP option 240 on lan interface
optwifi-configure enable-ssid 240 lan

# Restart network to apply changes
/etc/init.d/network restart
```

### Manual Configuration

Alternatively, configure manually via UCI:

```bash
# Enable the feature
uci set optwifi.settings.enabled=1

# Set DHCP option number (240 is example - use private range 224-254)
uci set optwifi.settings.ssid_dhcp_option=240

# Optional: Enable debug logging
uci set optwifi.settings.log_level=debug

# Commit changes
uci commit optwifi

# Configure network interface to request the DHCP option
uci set network.lan.reqopts='240'
uci commit network

# Restart network
/etc/init.d/network restart
```

## Verifying Installation

### Check installed files:
```bash
opkg files optwifi
```

### Check configuration:
```bash
cat /etc/config/optwifi
```

### View logs:
```bash
logread | grep optwifi
```

### Test DHCP option processing:
```bash
# Trigger DHCP renewal
killall -USR1 udhcpc

# Check logs for optwifi activity
logread -f | grep optwifi
```

## DHCP Server Configuration

Configure your DHCP server to send the custom option:

### dnsmasq (common on OpenWrt routers)
```bash
# In /etc/dnsmasq.conf or /etc/config/dhcp
dhcp-option=240,4d795353494400  # "MySSID" in hex
```

### ISC DHCP Server
```
option custom-ssid code 240 = text;
option custom-ssid "MySSID";
```

### Windows DHCP Server
1. Open DHCP management console
2. Go to Server Options
3. Add option 240 as String
4. Set value to hex-encoded SSID

## Package Contents

```
/etc/config/optwifi              # UCI configuration file
/etc/udhcpc.user.d/50-optwifi    # DHCP hook script
/usr/lib/optwifi/util.sh         # Utility functions
/usr/lib/optwifi/core.sh         # Core logic
/usr/bin/optwifi-configure       # Helper script
```

## Uninstallation

```bash
opkg remove optwifi
```

The package will automatically:
- Disable the feature (set enabled=0)
- Keep configuration file (marked as conffile)

To completely remove including config:
```bash
opkg remove optwifi
rm /etc/config/optwifi
```

## Troubleshooting

### Architecture mismatch error
**Error:** `incompatible with the architectures configured`

**Cause:** Some OpenWrt versions don't recognize `Architecture: all` for arch-independent packages.

**Solution:** Install with architecture override (package contains only shell scripts, works on any architecture):
```bash
# Install with --force-architecture flag
opkg install --force-architecture /tmp/optwifi_1.0.0-1_all.ipk
```

**Alternative:** Add 'all' architecture to opkg permanently:
```bash
echo "arch all 1" >> /etc/opkg.conf
opkg install /tmp/optwifi_1.0.0-1_all.ipk
```

### Dependency errors
**Error:** `cannot find dependency udhcpc`

**Cause:** Old build script listed udhcpc as dependency (it's part of busybox).

**Solution:** Rebuild with updated script:
```bash
./build-package.sh
# The new package only depends on libuci
```

### Package won't install
- Check dependencies: `opkg info optwifi`
- Ensure `libuci` is installed (standard on all OpenWrt)
- Verify package architecture matches router

### Feature not working
1. Check if enabled: `uci get optwifi.settings.enabled`
2. Check DHCP option configured: `uci get optwifi.settings.ssid_dhcp_option`
3. Check interface requests option: `uci get network.lan.reqopts`
4. Check logs: `logread | grep optwifi`
5. Enable debug: `uci set optwifi.settings.log_level=debug && uci commit`

### SSID not changing
1. Verify DHCP server is sending the option
2. Check hex encoding is correct (use online converter)
3. Verify SSID is valid (max 32 bytes)
4. Check logs for validation errors

## Architecture Compatibility

The package is architecture-independent (`Architecture: all`) since it contains only shell scripts.

Works on all OpenWrt architectures:
- mips / mipsel
- arm / aarch64
- x86 / x86_64
- Any other architecture supported by OpenWrt

## Security Notes

- **Disabled by default** - Must be explicitly enabled
- **Input validation** - Hex strings validated before decoding
- **Code/data separation** - Network data never evaluated by shell
- **SSID validation** - Length and format checks per 802.11 spec
- **No sensitive defaults** - All configuration requires user action
