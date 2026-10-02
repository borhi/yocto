SUMMARY = "Wi-Fi client configuration for wlan0 (wpa_supplicant, WPA2-PSK)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Passed in from the environment by scripts/build.sh (from .env):
#   WIFI_SSID_HEX - SSID as hex, so any characters are safe in the config
#   WIFI_PSK_HEX  - 256-bit PSK derived from the passphrase (wpa_passphrase)
#   WIFI_COUNTRY  - ISO 3166-1 alpha-2 regulatory domain, e.g. UA
WIFI_SSID_HEX ??= ""
WIFI_PSK_HEX ??= ""
WIFI_COUNTRY ??= ""

python () {
    if not d.getVar('WIFI_SSID_HEX') or not d.getVar('WIFI_PSK_HEX'):
        raise bb.parse.SkipRecipe("Wi-Fi is not configured (WIFI_SSID/WIFI_PSK in .env)")
}

do_install() {
    install -d -m 0755 ${D}${sysconfdir}/wpa_supplicant
    # printf, not a heredoc: a bare "}" line would end the BitBake function
    printf '%s\n' \
        'ctrl_interface=/var/run/wpa_supplicant' \
        'update_config=0' \
        'country=${WIFI_COUNTRY}' \
        '' \
        'network={' \
        '    ssid=${WIFI_SSID_HEX}' \
        '    psk=${WIFI_PSK_HEX}' \
        '    key_mgmt=WPA-PSK' \
        '}' > ${D}${sysconfdir}/wpa_supplicant/wpa_supplicant-wlan0.conf
    chmod 0600 ${D}${sysconfdir}/wpa_supplicant/wpa_supplicant-wlan0.conf
}

FILES:${PN} = "${sysconfdir}/wpa_supplicant"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# brcmfmac driver + CYW43455 firmware of the Pi 5 and the regulatory database
RDEPENDS:${PN} = " \
    wpa-supplicant \
    iw \
    wireless-regdb-static \
    kernel-module-brcmfmac \
    linux-firmware-rpidistro-bcm43455 \
    linux-firmware-rpidistro-bcm43456 \
    "
