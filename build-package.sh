#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Standalone package builder for optwifi
# Creates an installable .ipk package for OpenWrt

set -e

PKG_NAME="optwifi"

# Source version information
if [ ! -f VERSION ]; then
	echo "ERROR: VERSION file not found"
	exit 1
fi
. ./VERSION
# For architecture-independent packages (shell scripts only)
# OpenWrt accepts: 'all', 'noarch', or '*'
# Using 'all' as it's most widely supported across OpenWrt versions
PKG_ARCH="all"

BUILD_DIR="./build"
PACKAGE_DIR="${BUILD_DIR}/${PKG_NAME}_${PKG_VERSION}-${PKG_RELEASE}"
CONTROL_DIR="${PACKAGE_DIR}/CONTROL"
DATA_DIR="${PACKAGE_DIR}/data"

echo "=== Building ${PKG_NAME} ${PKG_VERSION}-${PKG_RELEASE} ==="
echo "Architecture: ${PKG_ARCH} (architecture-independent)"
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf "${BUILD_DIR}"
mkdir -p "${CONTROL_DIR}"
mkdir -p "${DATA_DIR}"

# Run tests first
echo "Running tests..."
if ! sh tests/test_runner.sh; then
    echo "ERROR: Tests failed! Fix issues before building."
    exit 1
fi
echo ""

# Create directory structure
echo "Creating package structure..."
mkdir -p "${DATA_DIR}/etc/config"
mkdir -p "${DATA_DIR}/etc/udhcpc.user.d"
mkdir -p "${DATA_DIR}/usr/lib/optwifi"
mkdir -p "${DATA_DIR}/usr/bin"

# Copy files
echo "Copying files..."
cp files/etc/config/optwifi "${DATA_DIR}/etc/config/optwifi"
cp files/etc/udhcpc.user.d/50-optwifi "${DATA_DIR}/etc/udhcpc.user.d/50-optwifi"
cp files/usr/lib/optwifi/util.sh "${DATA_DIR}/usr/lib/optwifi/util.sh"
cp files/usr/lib/optwifi/core.sh "${DATA_DIR}/usr/lib/optwifi/core.sh"
cp files/usr/bin/optwifi-configure "${DATA_DIR}/usr/bin/optwifi-configure"

# Set permissions
chmod 644 "${DATA_DIR}/etc/config/optwifi"
chmod 755 "${DATA_DIR}/etc/udhcpc.user.d/50-optwifi"
chmod 644 "${DATA_DIR}/usr/lib/optwifi/util.sh"
chmod 644 "${DATA_DIR}/usr/lib/optwifi/core.sh"
chmod 755 "${DATA_DIR}/usr/bin/optwifi-configure"

# Create control file
echo "Creating control file..."
cat > "${CONTROL_DIR}/control" <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}-${PKG_RELEASE}
Architecture: ${PKG_ARCH}
Maintainer: optwifi developers
Section: net
Priority: optional
Depends: libuci
Description: DHCP-triggered WiFi configuration
 Automatically configure WiFi SSID (and other parameters) via DHCP options.
 Disabled by default - must be explicitly enabled via UCI configuration.
 Requires udhcpc (usually part of busybox).
EOF

# Create conffiles
echo "Creating conffiles..."
cat > "${CONTROL_DIR}/conffiles" <<EOF
/etc/config/optwifi
EOF

# Create postinst script
echo "Creating postinst script..."
cat > "${CONTROL_DIR}/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
    echo "optwifi installed successfully!"
    echo ""
    echo "Quick setup:"
    echo "  optwifi-configure enable-ssid 240 lan"
    echo "  optwifi-configure enable-password 241 lan"
    echo "  /etc/init.d/network restart"
    echo ""
    echo "For help: optwifi-configure help"
}
exit 0
EOF
chmod 755 "${CONTROL_DIR}/postinst"

# Create prerm script
echo "Creating prerm script..."
cat > "${CONTROL_DIR}/prerm" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
    # Disable on removal
    uci -q set optwifi.settings.enabled=0 && uci commit optwifi
}
exit 0
EOF
chmod 755 "${CONTROL_DIR}/prerm"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "${DATA_DIR}" | cut -f1)
echo "Installed-Size: ${INSTALLED_SIZE}" >> "${CONTROL_DIR}/control"

# Create data tarball
echo "Creating data archive..."
cd "${DATA_DIR}"
tar czf ../data.tar.gz .
cd - > /dev/null

# Create control tarball
echo "Creating control archive..."
cd "${CONTROL_DIR}"
tar czf ../control.tar.gz .
cd - > /dev/null

# Create debian-binary
echo "2.0" > "${PACKAGE_DIR}/debian-binary"

# Create final .ipk package
IPK_FILE="${BUILD_DIR}/${PKG_NAME}_${PKG_VERSION}-${PKG_RELEASE}_${PKG_ARCH}.ipk"
echo "Creating .ipk package..."
cd "${PACKAGE_DIR}"
rm -f "$(basename ${IPK_FILE})"

# Modern OpenWrt (post-19.07) uses .ipk files that are gzipped tar archives
# containing debian-binary, control.tar.gz, and data.tar.gz
# Older versions used ar format, but tar.gz is more universally compatible
# and avoids BSD ar vs GNU ar incompatibility issues
#
# Package structure:
#   optwifi_1.0.0-1_all.ipk (gzipped tar)
#   ├── debian-binary (contains "2.0")
#   ├── control.tar.gz (package metadata)
#   └── data.tar.gz (files to install)
tar -czf "$(basename ${IPK_FILE})" debian-binary control.tar.gz data.tar.gz

mv "$(basename ${IPK_FILE})" ../
cd - > /dev/null

# Generate package info
echo ""
echo "=== Package Information ==="
echo "Package: ${IPK_FILE}"
echo "Size: $(du -h "${IPK_FILE}" | cut -f1)"
echo ""
echo "Contents:"
tar -tzf "${PACKAGE_DIR}/data.tar.gz" | sed 's/^/  /'
echo ""
echo "=== Build Complete ==="
echo ""
echo "To install on OpenWrt:"
echo "  1. Copy ${IPK_FILE} to your router"
echo "  2. Run: opkg install ${IPK_FILE}"
echo ""
echo "Or use SCP:"
echo "  scp ${IPK_FILE} root@router:/tmp/"
echo "  ssh root@router 'opkg install /tmp/$(basename ${IPK_FILE})'"
