#!/bin/bash
# Runs INSIDE the build container. /work is a case-sensitive Docker volume.
set -euo pipefail
BRANCH=scarthgap
cd /work

clone() { # url dir
    if [ ! -d "$2/.git" ]; then git clone -b "$BRANCH" --depth 1 "$1" "$2"; fi
}
clone https://git.yoctoproject.org/poky poky
clone https://github.com/agherzan/meta-raspberrypi.git meta-raspberrypi

for d in poky meta-raspberrypi; do echo "$d: $(git -C $d rev-parse HEAD)"; done

# Let the secrets computed on the host reach BitBake
export BB_ENV_PASSTHROUGH_ADDITIONS="RPI_USER_PASSWORD_HASH WIFI_SSID_HEX WIFI_PSK_HEX WIFI_COUNTRY"

set +u
source poky/oe-init-build-env /work/build > /dev/null
set -u

# (Re)apply our settings block: drop any previous copy, append the current one
sed -i '/custom settings (rpi5-ssh-image)/,$d' conf/local.conf
cat /layers/conf/local.conf.append >> conf/local.conf
bitbake-layers show-layers | grep -q meta-raspberrypi || bitbake-layers add-layer /work/meta-raspberrypi
bitbake-layers show-layers | grep -q meta-custom      || bitbake-layers add-layer /layers/meta-custom

bitbake -k rpi5-ssh-image

DEPLOY=/work/build/tmp/deploy/images/raspberrypi5
mkdir -p /out
cp -L "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.wic.bz2 \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.wic.bmap \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.tar.bz2 \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.manifest /out/
ls -lh /out
