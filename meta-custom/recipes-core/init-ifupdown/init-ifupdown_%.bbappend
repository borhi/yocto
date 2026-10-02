# When Wi-Fi is configured, bring wlan0 up at boot using our wpa_supplicant config.
# brcmfmac loads asynchronously (module + firmware), so wait for wlan0 to appear.
WIFI_SSID_HEX ??= ""
RPI_HOSTNAME ??= ""

do_install:append() {
    # Send our hostname with DHCP requests so the router lists the Pi by name
    if [ -n "${RPI_HOSTNAME}" ]; then
        sed -i -e '/^iface \(eth0\|wlan0\) inet dhcp/a \	hostname ${RPI_HOSTNAME}' \
            ${D}${sysconfdir}/network/interfaces
    fi
    if [ -n "${WIFI_SSID_HEX}" ]; then
        sed -i \
            -e '/^iface wlan0 inet dhcp/i auto wlan0' \
            -e '/^iface wlan0 inet dhcp/a \	pre-up n=0; while [ ! -e /sys/class/net/wlan0 ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done' \
            -e 's#wpa-driver wext#wpa-driver nl80211,wext#' \
            -e 's#wpa-conf /etc/wpa_supplicant.conf#wpa-conf /etc/wpa_supplicant/wpa_supplicant-wlan0.conf#' \
            ${D}${sysconfdir}/network/interfaces
    fi
}
do_install[vardeps] += "WIFI_SSID_HEX RPI_HOSTNAME"
