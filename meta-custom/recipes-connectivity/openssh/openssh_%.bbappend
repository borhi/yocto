FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://99-custom.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/ssh/sshd_config.d
    install -m 0644 ${WORKDIR}/99-custom.conf ${D}${sysconfdir}/ssh/sshd_config.d/99-custom.conf
}

FILES:${PN}-sshd += "${sysconfdir}/ssh/sshd_config.d"
