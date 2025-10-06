# optwifi - DHCP-Triggered WiFi Configuration for OpenWrt

Automatically configure WiFi parameters via DHCP options on OpenWrt routers.

## Use case

Manage multiple bridging APs across different sites. By delivering both network and WiFi settings via DHCP, you can maintain a stock of pre-configured APs that work automatically at any site without per-site configuration. The only prerequisite is registering each AP's MAC address with the site's DHCP server when adding it to inventory.

## Features

- **DHCP option-based configuration**: Receive WiFi settings from your DHCP server
- **Off by default**: Disabled unless explicitly configured
- **Configurable logging**: Track all configuration changes when they occur

## Current Capabilities

- Update WiFi SSID from DHCP option (applies to all radios)

## Installation

### Download the Package

Download the latest `.ipk` file from the [Releases page](https://github.com/distalzou/optwifi/releases).

### Install on Your Router

```bash
# Copy to router
scp optwifi_*.ipk root@192.168.1.1:/tmp/

# SSH into router and install
ssh root@192.168.1.1
opkg install /tmp/optwifi_*.ipk
```

The installer will display setup instructions when complete.

### Building from Source (Optional)

If you want to build from source instead of using a release:

```bash
./build-package.sh
```

See [INSTALL.md](INSTALL.md) for detailed installation instructions, building from source, and troubleshooting.

## Configuration

### Quick Setup (Recommended)

Use the helper script to configure everything in one command:

```bash
optwifi-configure enable-ssid 240 lan
/etc/init.d/network restart
```

This configures optwifi to use DHCP option 240 for SSID and sets the lan interface to request it. (DHCP options 224-254 are for private use.)

### Manual Configuration

If you prefer to configure manually:

```bash
# Enable optwifi and set DHCP option
uci set optwifi.settings.enabled=1
uci set optwifi.settings.ssid_dhcp_option=240
uci commit optwifi

# Configure network interface to request the option
uci set network.lan.reqopts='240'
uci commit network
/etc/init.d/network restart
```

### 3. Configure your DHCP server

Send option 240 with hex-encoded SSID. Examples:

**ISC DHCP Server:**
```
option custom-ssid code 240 = text;

host myrouter {
    hardware ethernet aa:bb:cc:dd:ee:ff;
    fixed-address 192.168.1.10;
    option custom-ssid "MySSID";
}
```

**dnsmasq:**
```
dhcp-option=240,"MySSID"
```

## Configuration Options

Edit `/etc/config/optwifi`:

```
config optwifi 'settings'
    option enabled '0'              # 0=disabled, 1=enabled
    option log_level 'info'         # 'error', 'info', or 'debug'
    option ssid_dhcp_option '240'   # DHCP option number for SSID
```

## How It Works

1. Router receives DHCP response with configured option
2. `udhcpc` hook script (`/etc/udhcpc.user.d/50-optwifi`) is triggered
3. If enabled, optwifi decodes the hex-encoded value
4. SSID is validated (length, format)
5. All wireless SSIDs are updated via UCI
6. WiFi is reloaded with new configuration

## Logging

View logs with:
```bash
logread | grep optwifi
```

Enable debug logging:
```bash
uci set optwifi.settings.log_level=debug
uci commit optwifi
```

## File Structure

```
/etc/config/optwifi                  # UCI configuration
/etc/udhcpc.user.d/50-optwifi        # DHCP hook (entry point)
/usr/lib/optwifi/util.sh             # Utility functions
/usr/lib/optwifi/core.sh             # Core logic
```

## Security

- **Disabled by default** - Requires explicit user configuration
- **Input validation**:
  - SSID length (0-32 bytes per 802.11 spec)
  - Hex format validation (even length, valid hex digits)
  - Control character rejection (0x00-0x1F, 0x7F)
- **Comprehensive logging** - All actions and errors logged
- **UTF-8 support** - International SSIDs supported

## Future Enhancements

Planned features:
- WPA password configuration via DHCP
- Per-interface SSID control
- Additional wireless parameters (channel, encryption mode, etc.)

## Troubleshooting

**SSID not updating:**
1. Check status: `optwifi-configure status`
2. Check if enabled: `uci get optwifi.settings.enabled`
3. Verify option configured: `uci get optwifi.settings.ssid_dhcp_option`
4. Check network interface requests option: `uci get network.lan.reqopts`
5. View logs: `logread | grep optwifi`
6. Enable debug logging for more details

**DHCP option not received:**
1. Verify DHCP server configuration
2. Check interface is requesting option: `uci show network | grep reqopts`
3. Capture DHCP traffic: `tcpdump -i eth0 port 67 or port 68`

## Testing

Run the automated test suite:
```bash
sh tests/test_runner.sh
```

Tests validate:
- Shell script syntax
- Function definitions
- SSID validation logic
- Code quality checks

For detailed information about the test framework, see [tests/README.md](tests/README.md).

## License

GPL-2.0-or-later

This project is licensed under the GNU General Public License v2.0 or later, matching the OpenWrt ecosystem. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Areas of interest:
- Security hardening
- Additional DHCP options support
- Interface-specific configuration
- Testing on various OpenWrt versions
