################################################################################
#
# zerotier-one
#
################################################################################

ZEROTIERONE_VERSION = 1.12.2
ZEROTIERONE_SOURCE = ZeroTierOne-$(ZEROTIERONE_VERSION).tar.gz
ZEROTIERONE_SITE = https://github.com/zerotier/ZeroTierOne/archive/refs/tags/$(ZEROTIERONE_VERSION)
ZEROTIERONE_LICENSE = BSL-1.0 (Core), GPL-3.0+ (Client)
ZEROTIERONE_LICENSE_FILES = LICENSE.txt
ZEROTIERONE_DEPENDENCIES = libminiupnpc

define ZEROTIERONE_BUILD_CMDS
    $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) one
endef

define ZEROTIERONE_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/zerotier-one $(TARGET_DIR)/usr/sbin/zerotier-one
endef

 $(eval $(generic-package))
