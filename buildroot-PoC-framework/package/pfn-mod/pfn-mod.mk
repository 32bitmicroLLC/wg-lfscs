################################################################################
#
# pfn-mod
#
################################################################################

PFN_MOD_VERSION = 1.0
PFN_MOD_SITE = $(PFN_MOD_PKGDIR)/src
PFN_MOD_SITE_METHOD = local
PFN_MOD_LICENSE = GPL-2.0-only

PFN_MOD_DEPENDENCIES = linux

# Build the out-of-tree kernel module from package/pfn-mod/src/Makefile.
PFN_MOD_MODULE_SUBDIRS = .

$(eval $(kernel-module))

define PFN_MOD_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/pfn-mod
	$(INSTALL) -m 0644 $(@D)/pfn_slab_probe.ko \
		$(TARGET_DIR)/usr/pfn-mod/pfn_slab_probe.ko
endef

$(eval $(generic-package))
