#!/usr/bin/env bash
set -euo pipefail
export NIX_CONFIG="experimental-features = nix-command flakes"
FLAKE="git+https://github.com/Edwinakamosez/dawo-werkplek#laptop-sata"

echo "=== DAWO installatie: dit WIST /dev/sda ==="
lsblk
read -r -p "Typ JA om door te gaan: " ANTWOORD </dev/tty
[ "$ANTWOORD" = "JA" ] || { echo "Afgebroken."; exit 1; }

# TIJDELIJK LUKS-wachtwoord, alleen voor testen
echo -n "WijzigMij-Na-Eerste-Boot" > /tmp/secret.key

nix shell nixpkgs#git --command bash -c '
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks \
    --no-write-lock-file --flake "$0" &&
  nixos-install --flake "$0" --no-root-passwd
' "$FLAKE"

reboot
