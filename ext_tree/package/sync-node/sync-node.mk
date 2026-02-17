################################################################################
#
# sync-node
#
################################################################################

SYNC_NODE_VERSION = 1.0
SYNC_NODE_SITE = $(BR2_EXTERNAL_ext_tree_PATH)/package/sync-node
SYNC_NODE_SITE_METHOD = local

define SYNC_NODE_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" -C $(@D)
endef

define SYNC_NODE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sync_node $(TARGET_DIR)/opt/sync_node
endef

$(eval $(generic-package))
