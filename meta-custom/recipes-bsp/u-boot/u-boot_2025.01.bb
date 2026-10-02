# U-Boot 2025.01 for the Raspberry Pi 5.
# scarthgap ships U-Boot 2024.01, which predates BCM2712 support (memory map,
# board revision, sdhci-brcmstb); Pi 5 support landed upstream in v2024.04.
# Based on poky's u-boot_2024.01.bb/u-boot-common.inc without the 2024.01 CVE
# backports, which are already part of this release.
HOMEPAGE = "https://u-boot.org"
DESCRIPTION = "U-Boot, a boot loader for Embedded boards based on PowerPC, \
ARM, MIPS and several other processors."
SECTION = "bootloaders"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=2ca5f2c35c8cc335f0a19756634782f1"
PE = "1"

CVE_PRODUCT = "u-boot:u-boot denx:u-boot"

# v2025.01
SRCREV = "6d41f0a39d6423c8e57e92ebbe9f8c0333a63f72"
SRC_URI = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master"

S = "${WORKDIR}/git"
B = "${WORKDIR}/build"

DEPENDS += "flex-native bison-native python3-setuptools-native \
            bc-native dtc-native gnutls-native python3-pyelftools-native"

inherit pkgconfig

do_configure[cleandirs] = "${B}"

require recipes-bsp/u-boot/u-boot.inc
