# OpenWrt Makefile for optwifi
include $(TOPDIR)/rules.mk

PKG_NAME:=optwifi
PKG_VERSION:=0.9.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Your Name <your.email@example.com>

include $(INCLUDE_DIR)/package.mk

define Package/optwifi
  SECTION:=net
  CATEGORY:=Network
  TITLE:=DHCP-triggered WiFi configuration
  DEPENDS:=+libuci +udhcpc
  PKGARCH:=all
endef

define Package/optwifi/description
  Automatically configure WiFi SSID (and other parameters) via DHCP options.
  Disabled by default - must be explicitly enabled via UCI configuration.
endef

define Build/Compile
	# No compilation needed - shell scripts only
endef

define Build/RunTests
	@echo "Running tests..."
	@cd $(PKG_BUILD_DIR) && sh tests/test_runner.sh
endef

define Package/optwifi/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/optwifi $(1)/etc/config/optwifi

	$(INSTALL_DIR) $(1)/etc/udhcpc.user.d
	$(INSTALL_BIN) ./files/etc/udhcpc.user.d/50-optwifi $(1)/etc/udhcpc.user.d/50-optwifi

	$(INSTALL_DIR) $(1)/usr/lib/optwifi
	$(INSTALL_DATA) ./files/usr/lib/optwifi/util.sh $(1)/usr/lib/optwifi/util.sh
	$(INSTALL_DATA) ./files/usr/lib/optwifi/core.sh $(1)/usr/lib/optwifi/core.sh

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/optwifi-configure $(1)/usr/bin/optwifi-configure
endef

define Package/optwifi/conffiles
/etc/config/optwifi
endef

define Package/optwifi/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Ensure udhcpc requests the configured DHCP option
	# This will be done manually by user via documentation
	echo "optwifi installed successfully!"
	echo ""
	echo "Quick setup:"
	echo "  optwifi-configure enable-ssid 240 lan"
	echo "  /etc/init.d/network restart"
	echo ""
	echo "For help: optwifi-configure help"
}
exit 0
endef

define Package/optwifi/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Disable on removal
	uci -q set optwifi.settings.enabled=0 && uci commit optwifi
}
exit 0
endef

$(eval $(call BuildPackage,optwifi))
