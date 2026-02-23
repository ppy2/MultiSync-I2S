################################################################################
#
# llmnrd - Link-Local Multicast Name Resolution daemon
#
################################################################################

LLMNRD_VERSION = 0.7
LLMNRD_SITE = https://github.com/tklauser/llmnrd/archive/refs/tags
LLMNRD_SOURCE = v$(LLMNRD_VERSION).tar.gz
LLMNRD_SHA256 = c88086b5a926e8801154a0119de6a497a3891581a0219a0ef8d9d8e98556eb9b

define LLMNRD_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) llmnrd llmnr-query
endef

define LLMNRD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/llmnrd  $(TARGET_DIR)/usr/sbin/llmnrd
	$(INSTALL) -D -m 0755 $(@D)/llmnr-query $(TARGET_DIR)/usr/bin/llmnr-query
endef

$(eval $(generic-package))
