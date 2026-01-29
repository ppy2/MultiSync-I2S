################################################################################
#
# alsa-drain-wrapper
#
################################################################################

ALSA_DRAIN_WRAPPER_VERSION = 1.0
ALSA_DRAIN_WRAPPER_SITE = $(BR2_EXTERNAL_ext_tree_PATH)/package/alsa-drain-wrapper
ALSA_DRAIN_WRAPPER_SITE_METHOD = local
ALSA_DRAIN_WRAPPER_DEPENDENCIES = alsa-lib

define ALSA_DRAIN_WRAPPER_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" -C $(@D)
endef

define ALSA_DRAIN_WRAPPER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libasound_nodrain.so $(TARGET_DIR)/usr/lib/libasound_nodrain.so
endef

$(eval $(generic-package))
