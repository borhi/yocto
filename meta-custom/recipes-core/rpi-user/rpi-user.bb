SUMMARY = "Login user 'pi' with SSH public-key access and sudo rights"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://authorized_keys"
S = "${WORKDIR}"

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-r sudo"
# SHA-512 crypt hash with every '$' escaped as '\$'. Passed in from the
# environment by scripts/build.sh (computed from PI_PASSWORD in .env).
RPI_USER_PASSWORD_HASH ??= ""

python () {
    if not d.getVar('RPI_USER_PASSWORD_HASH'):
        bb.fatal("RPI_USER_PASSWORD_HASH is not set: define PI_PASSWORD in .env and build with scripts/build.sh")
}
USERADD_PARAM:${PN} = "-m -d /home/pi -s /bin/sh -G sudo -p '${RPI_USER_PASSWORD_HASH}' pi"

do_install() {
    install -d -m 0700 ${D}/home/pi/.ssh
    install -m 0600 ${WORKDIR}/authorized_keys ${D}/home/pi/.ssh/authorized_keys
    chown -R pi:pi ${D}/home/pi

    install -d -m 0750 ${D}${sysconfdir}/sudoers.d
    echo "%sudo ALL=(ALL:ALL) ALL" > ${D}${sysconfdir}/sudoers.d/10-sudo-group
    chmod 0440 ${D}${sysconfdir}/sudoers.d/10-sudo-group
}

FILES:${PN} = "/home/pi ${sysconfdir}/sudoers.d"
RDEPENDS:${PN} = "sudo"
