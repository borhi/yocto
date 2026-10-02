#!/bin/bash
# Functional SSH check of the built rootfs without real hardware.
# The RPi5 rootfs is aarch64, same as Apple Silicon, so its binaries run natively
# in a container: we start the image's own sshd and log in from the host.
# sshd is started via the image's init script (/etc/init.d/sshd), which generates
# host keys and creates /var/run/sshd exactly as on the first boot of the Pi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAR="$ROOT/deploy/rpi5-ssh-image-raspberrypi5.rootfs.tar.bz2"
set -a; source "$ROOT/.env"; set +a
# Private key matching SSH_PUBKEY from .env (override with KEY=...)
PUB="${SSH_PUBKEY:-~/.ssh/id_ed25519.pub}"
KEY="${KEY:-${PUB/#\~/$HOME}}"
KEY="${KEY%.pub}"
PORT=2222
SSH_OPTS=(-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o IdentitiesOnly=yes)

docker rm -f rpi5-ssh-test >/dev/null 2>&1 || true
docker import "$TAR" rpi5-ssh-image:latest >/dev/null
docker run -d --name rpi5-ssh-test -p $PORT:22 rpi5-ssh-image:latest \
    /bin/sh -c '/etc/init.d/sshd start && exec tail -f /dev/null' >/dev/null
trap 'docker rm -f rpi5-ssh-test >/dev/null' EXIT
until docker exec rpi5-ssh-test sh -c "test -s /run/sshd.pid" 2>/dev/null; do sleep 0.5; done; sleep 1

echo "== 1. public-key login as pi"
ssh "${SSH_OPTS[@]}" -i "$KEY" -o PasswordAuthentication=no pi@localhost \
    'echo "logged in as $(id -un) ($(id))"; echo "arch: $(uname -m)"; cat /etc/issue.net; ls -l ~/.ssh'
echo "baked-in hostname: $(tar -xjOf "$TAR" ./etc/hostname)"

echo "== 2. password login as pi"
ASK=$(mktemp); printf '#!/bin/sh\necho "$PI_PASSWORD"\n' > "$ASK"; chmod +x "$ASK"
PI_PASSWORD="$PI_PASSWORD" SSH_ASKPASS="$ASK" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no -o PreferredAuthentications=password pi@localhost 'echo "password auth OK"'
rm -f "$ASK"

echo "== 3. root login must be rejected"
if ssh "${SSH_OPTS[@]}" -i "$KEY" -o BatchMode=yes root@localhost true 2>/dev/null; then
    echo "FAIL: root login allowed"; exit 1
else
    echo "root login rejected: OK"
fi

echo "== 4. effective sshd config"
docker exec rpi5-ssh-test /usr/sbin/sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) '
echo "ALL SSH CHECKS PASSED"
