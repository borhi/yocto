# Custom Yocto image for Raspberry Pi 5 with SSH

Minimal Linux image built with Yocto 5.0 **scarthgap** + `meta-raspberrypi`
(`MACHINE = "raspberrypi5"`). The Pi boots through U-Boot, gets an IP via DHCP
on Ethernet and/or Wi-Fi, and starts OpenSSH.

## Layout

```
Dockerfile               Ubuntu 22.04 build environment
.env.dist                template for .env (passwords, SSH key, Wi-Fi)
conf/local.conf.append   build settings (machine, U-Boot, hostname, ...)
meta-custom/             custom layer
  recipes-core/images/         rpi5-ssh-image
  recipes-core/rpi-user/       user "pi", sudo, authorized_keys
  recipes-core/init-ifupdown/  wlan0 autostart, DHCP hostname
  recipes-connectivity/        sshd policy, Wi-Fi config
  recipes-bsp/u-boot/          U-Boot 2025.01
scripts/build.sh         build (runs bitbake in Docker)
scripts/verify-ssh.sh    SSH check without hardware
deploy/                  build output
```

## Configure

```sh
cp .env.dist .env
```

| Variable | Meaning |
|---|---|
| `PI_PASSWORD` | password of user `pi` (SSH and sudo), required |
| `SSH_PUBKEY` | public key allowed to log in, default `~/.ssh/id_ed25519.pub` |
| `WIFI_SSID` | Wi-Fi network name, case-sensitive; empty means Ethernet only |
| `WIFI_PSK` | Wi-Fi password, 8–63 characters |
| `WIFI_COUNTRY` | regulatory domain, e.g. `UA` |

`.env` is git-ignored. No secrets reach git or the image in plain text: the
build puts only a SHA-512 hash of `PI_PASSWORD` and the derived WPA PSK into
the image.

## Build

```sh
./scripts/build.sh
```

Sources and build dirs live in the `yocto-work` Docker volume, because Yocto
needs a case-sensitive filesystem. The first build takes 1–2 h; later builds
take minutes, thanks to sstate.

## Flash

Find the SD card with `diskutil list external`, then:

```sh
diskutil unmountDisk /dev/diskN
bzcat deploy/rpi5-ssh-image-raspberrypi5.rootfs.wic.bz2 | sudo dd of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

`dd` overwrites the whole disk, so double-check `N`.

To use **Raspberry Pi Imager** instead, unpack the image first, then pick
*Use Custom*. Answer **No** to *OS customisation*, because the image is
already configured from `.env`.

```sh
bunzip2 -kc deploy/rpi5-ssh-image-raspberrypi5.rootfs.wic.bz2 > deploy/rpi5-yocto.img
```

## Connect

```sh
ssh -i ~/.ssh/id_ed25519 pi@<ip>    # the key from SSH_PUBKEY, or PI_PASSWORD
```

- The Pi sends hostname `rpi5-yocto` with DHCP, so look for it in the router's
  client list.
- `pi` is in the `sudo` group. Root login over SSH is disabled (`AllowUsers pi`).
- Host keys are generated on first boot. After reflashing, ssh warns
  *REMOTE HOST IDENTIFICATION HAS CHANGED*. This is expected; clear the old
  entry with `ssh-keygen -R <ip>`.
- Local console: HDMI + USB keyboard (`tty1`) or UART at 115200.

## Wi-Fi

When `WIFI_SSID` is set, `wlan0` comes up at boot via `wpa_supplicant` and DHCP.
The config lives in `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` (mode 0600).

- Only WPA2-PSK (or WPA2/WPA3 mixed) works, not WPA3-only: the image stores
  the derived PSK instead of the passphrase.
- On 5 GHz, avoid DFS channels (52–144) if the Pi doesn't see the network.

## U-Boot

Boot chain: Pi firmware → U-Boot (`kernel_2712.img`) → `boot.scr` → Linux
`Image`, using the device tree from the firmware. U-Boot comes from
`meta-custom/recipes-bsp/u-boot`, because scarthgap's 2024.01 has no Pi 5
support (that arrived in 2024.04). The autoboot delay is disabled, so U-Boot
never waits for UART input. To boot the kernel directly, remove
`RPI_USE_U_BOOT` from `conf/local.conf.append`.

## Verify SSH without a Pi

```sh
./scripts/verify-ssh.sh
```

QEMU can't emulate the Pi 5. The rootfs is aarch64, though, so the script runs
it natively in Docker on Apple Silicon, starts sshd through the image's own
init script, and checks:

- key login works
- password login works
- root login is rejected
- the `sshd -T` config is as expected

This doesn't test the kernel, the bootloader or Wi-Fi.

## Troubleshooting

On the Pi (HDMI console or Ethernet):

```sh
ip addr show wlan0               # interface present, IP assigned?
dmesg | grep -i brcmfmac         # driver and firmware loaded?
sudo wpa_cli -i wlan0 status     # wpa_state=COMPLETED?
sudo iw dev wlan0 scan | grep -i ssid
```

Build on an 8 GB RAM host:

- Parallelism is capped at 4 jobs to avoid OOM.
- `ptest` is removed from `DISTRO_FEATURES`. Its packages would pull target
  gcc, python3 and perl into the build.
- If `linux-raspberrypi:do_fetch` fails on the huge kernel clone, seed a
  shallow mirror of `SRCREV_machine` into
  `downloads/git2/github.com.raspberrypi.linux.git` (branch `rpi-6.6.y`).
