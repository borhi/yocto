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
clone https://git.openembedded.org/meta-openembedded meta-openembedded
clone https://git.yoctoproject.org/meta-virtualization meta-virtualization

for d in poky meta-raspberrypi meta-openembedded meta-virtualization; do echo "$d: $(git -C $d rev-parse HEAD)"; done

# Let the secrets computed on the host reach BitBake
export BB_ENV_PASSTHROUGH_ADDITIONS="RPI_USER_PASSWORD_HASH WIFI_SSID_HEX WIFI_PSK_HEX WIFI_COUNTRY"

set +u
source poky/oe-init-build-env /work/build > /dev/null
set -u

# (Re)apply our settings block: drop any previous copy, append the current one
sed -i '/custom settings (rpi5-ssh-image)/,$d' conf/local.conf
cat /layers/conf/local.conf.append >> conf/local.conf
# Layers in dependency order; meta-virtualization needs meta-oe, meta-python,
# meta-networking and meta-filesystems
LAYERS="/work/meta-raspberrypi
        /work/meta-openembedded/meta-oe
        /work/meta-openembedded/meta-python
        /work/meta-openembedded/meta-networking
        /work/meta-openembedded/meta-filesystems
        /work/meta-virtualization
        /layers/meta-custom"
CURRENT=$(bitbake-layers show-layers)
for l in $LAYERS; do
    echo "$CURRENT" | grep -q " $l " || bitbake-layers add-layer "$l"
done

bitbake -k rpi5-ssh-image

DEPLOY=/work/build/tmp/deploy/images/raspberrypi5
mkdir -p /out
cp -L "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.wic.bz2 \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.wic.bmap \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.tar.bz2 \
      "$DEPLOY"/rpi5-ssh-image-raspberrypi5.rootfs.manifest /out/
ls -lh /out
