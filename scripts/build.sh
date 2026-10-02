#!/bin/bash
# Host entry point: builds the container and runs the Yocto build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Local settings and secrets (see .env.dist)
[ -f "$ROOT/.env" ] || { echo "Missing .env: cp .env.dist .env and fill it in"; exit 1; }
set -a; source "$ROOT/.env"; set +a
[ -n "${PI_PASSWORD:-}" ] || { echo "PI_PASSWORD is empty in .env"; exit 1; }

# Public key allowed to log in as "pi"; kept out of git
KEYS="$ROOT/meta-custom/recipes-core/rpi-user/files/authorized_keys"
SSH_PUBKEY="${SSH_PUBKEY:-~/.ssh/id_ed25519.pub}"
SSH_PUBKEY="${SSH_PUBKEY/#\~/$HOME}"
[ -f "$SSH_PUBKEY" ] || { echo "No SSH public key at $SSH_PUBKEY (set SSH_PUBKEY in .env)"; exit 1; }
cp "$SSH_PUBKEY" "$KEYS"

docker build -t yocto-builder:scarthgap "$ROOT"

# SHA-512 crypt hash of the password; '$' escaped for the useradd shell code
HASH=$(printf '%s' "$PI_PASSWORD" | docker run --rm -i yocto-builder:scarthgap openssl passwd -6 -stdin)
export RPI_USER_PASSWORD_HASH="${HASH//\$/\\\$}"
docker volume create yocto-work >/dev/null
# Volume is created root-owned; hand it to the builder user
docker run --rm -v yocto-work:/work -u root yocto-builder:scarthgap chown builder:builder /work

# Optional Wi-Fi: hex SSID + PSK derived like wpa_passphrase (PBKDF2-SHA1, 4096 rounds)
WIFI_SSID_HEX="" WIFI_PSK_HEX=""
if [ -n "${WIFI_SSID:-}" ]; then
    [ ${#WIFI_PSK} -ge 8 ] && [ ${#WIFI_PSK} -le 63 ] || { echo "WIFI_PSK must be 8..63 characters"; exit 1; }
    [[ "${WIFI_COUNTRY:-}" =~ ^[A-Z]{2}$ ]] || { echo "WIFI_COUNTRY must be a 2-letter code, e.g. UA"; exit 1; }
    read -r WIFI_SSID_HEX WIFI_PSK_HEX < <(printf '%s\n%s' "$WIFI_SSID" "$WIFI_PSK" | \
        docker run --rm -i yocto-builder:scarthgap python3 -c '
import sys, hashlib
ssid, psk = sys.stdin.read().split("\n", 1)
print(ssid.encode().hex(), hashlib.pbkdf2_hmac("sha1", psk.encode(), ssid.encode(), 4096, 32).hex())')
fi
export WIFI_SSID_HEX WIFI_PSK_HEX WIFI_COUNTRY="${WIFI_COUNTRY:-}"

docker run --rm --name yocto-build \
    -e RPI_USER_PASSWORD_HASH -e WIFI_SSID_HEX -e WIFI_PSK_HEX -e WIFI_COUNTRY \
    -v yocto-work:/work \
    -v "$ROOT/meta-custom":/layers/meta-custom:ro \
    -v "$ROOT/conf":/layers/conf:ro \
    -v "$ROOT/scripts":/layers/scripts:ro \
    -v "$ROOT/deploy":/out \
    yocto-builder:scarthgap /layers/scripts/container-build.sh
