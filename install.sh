#!/usr/bin/env bash
set -euo pipefail
export NIX_CONFIG="experimental-features = nix-command flakes"

DISK=/dev/sda
REPO=https://github.com/Edwinakamosez/dawo-werkplek.git
HOST=laptop-sata

[ "$(id -u)" -eq 0 ] || { echo "Draai dit als root: sudo bash /tmp/install.sh"; exit 1; }
[ "$(lsblk -ndo TRAN "$DISK")" != "usb" ] || { echo "FOUT: $DISK is USB. Gestopt."; exit 1; }
cd /tmp

echo "=== DAWO installatie: dit WIST $DISK volledig ==="
lsblk "$DISK"
read -r -p "Typ JA om door te gaan: " ANTWOORD </dev/tty
[ "$ANTWOORD" = "JA" ] || { echo "Afgebroken."; exit 1; }

echo "=== Stap 1: repo ophalen en vastpinnen ==="
rm -rf /tmp/werkplek
nix shell nixpkgs#git --command git clone --depth 1 "$REPO" /tmp/werkplek
nix shell nixpkgs#git --command nix flake lock /tmp/werkplek
FLAKE="/tmp/werkplek#$HOST"

echo "=== Stap 2: schijf loskoppelen en schoonmaken ==="
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
for m in $(lsblk -nrpo NAME,TYPE "$DISK" | awk '$2=="crypt"{print $1}'); do
  cryptsetup close "$m" || true
done
wipefs -a "$DISK"
nix shell nixpkgs#gptfdisk --command sgdisk --zap-all "$DISK"
dd if=/dev/zero of="$DISK" bs=1M count=20 conv=fsync
partprobe "$DISK" || true
udevadm settle

echo "=== Stap 3: LUKS-wachtwoord (tijdelijk, alleen voor testen) ==="
echo -n "WijzigMij-Na-Eerste-Boot" > /tmp/secret.key

echo "=== Stap 4: partitioneren met disko ==="
nix shell nixpkgs#git --command \
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"

echo "=== Stap 5: installeren ==="
nix shell nixpkgs#git --command \
  nixos-install --flake "$FLAKE" --no-root-passwd

echo "=== Klaar, herstart ==="
reboot
