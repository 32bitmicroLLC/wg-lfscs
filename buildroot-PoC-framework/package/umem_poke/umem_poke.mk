################################################################################
#
# umem_poke
#
################################################################################

UMEM_POKE_VERSION = 1.0
UMEM_POKE_SITE = $(UMEM_POKE_PKGDIR)/src
UMEM_POKE_SITE_METHOD = local
UMEM_POKE_LICENSE = GPL-2.0

UMEM_POKE_MODULE_SUBDIRS = kmod

ifeq ($(BR2_aarch64),y)
UMEM_POKE_VICTIM_ASM = victim/aarch64_sleep_print_simple.as
else ifeq ($(BR2_x86_64),y)
UMEM_POKE_VICTIM_ASM = victim/x86_64_sleep_print_simple.as
endif

define UMEM_POKE_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-x assembler-with-cpp \
		-nostdlib -static \
		-o $(@D)/umem_poke_victim \
		$(@D)/$(UMEM_POKE_VICTIM_ASM)
endef

define UMEM_POKE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/umem_poke
	$(INSTALL) -m 0755 $(@D)/umem_poke_victim \
		$(TARGET_DIR)/usr/umem_poke/umem_poke_victim
	$(INSTALL) -m 0644 $(@D)/kmod/*.ko \
		$(TARGET_DIR)/usr/umem_poke/
	$(INSTALL) -m 0755 $(@D)/poc.sh \
		$(TARGET_DIR)/usr/umem_poke/poc.sh
endef

$(eval $(kernel-module))
$(eval $(generic-package))
