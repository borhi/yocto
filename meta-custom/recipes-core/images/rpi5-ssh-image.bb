SUMMARY = "Minimal custom Raspberry Pi 5 image with OpenSSH remote access"
LICENSE = "MIT"

inherit core-image

# MACHINE_EXTRA_RRECOMMENDS: kernel modules, udev rules and Wi-Fi/BT firmware
# that meta-raspberrypi expects (normally pulled in by packagegroup-base).
# wifi-config is added only when Wi-Fi is set up in .env.

IMAGE_FEATURES += "ssh-server-openssh"

IMAGE_INSTALL = " \
    packagegroup-core-boot \
    ${CORE_IMAGE_EXTRA_INSTALL} \
    openssh-sftp-server \
    rpi-user \
    sudo \
    iproute2 \
    ros-core \
    ${MACHINE_EXTRA_RRECOMMENDS} \
    ${@'wifi-config' if d.getVar('WIFI_SSID_HEX') else ''} \
    "

IMAGE_LINGUAS = ""

# Extra space in the rootfs (KiB)
IMAGE_ROOTFS_EXTRA_SPACE = "262144"
