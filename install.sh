#!/usr/bin/env bash
set -euo pipefail
export NIX_CONFIG="experimental-features = nix-command flakes"

DISK=/dev/sda      # moet gelijk zijn aan het pad in hosts/laptop-sata.nix
REPO=https://github.com/Edwinakamosez/dawo-werkplek.git
HOST=laptop-sata

[ "$(id -u)" -eq 0 ] || { echo "Draai dit als root: sudo bash /tmp/install.sh"; exit 1; }
[ "$(lsblk -ndo TRAN "$DISK")" != "usb" ] || { echo "FOUT: $DISK is USB. Gestopt."; exit 1; }
cd /tmp

echo "=== DAWO installatie: dit WIST $DISK volledig ==="
lsblk "$DISK"
read -r -p "Typ JA om door te gaan: " ANTWOORD </dev/tty
[ "$ANTWOORD" = "JA" ] || { echo "Afgebroken."; exit 1; }

echo "=== Stap 1: LUKS-wachtwoord kiezen ==="
echo "Dit wachtwoord ontgrendelt de schijf. Zonder dit wachtwoord is er geen herstel."
while true; do
  read -r -s -p "Kies een LUKS-wachtwoord (min. 8 tekens): " PW1 </dev/tty; echo
  read -r -s -p "Herhaal het wachtwoord: " PW2 </dev/tty; echo
  if [ "${#PW1}" -lt 8 ]; then echo "Te kort, probeer opnieuw."
  elif [ "$PW1" != "$PW2" ]; then echo "Komt niet overeen, probeer opnieuw."
  else break; fi
done
umask 077
printf '%s' "$PW1" > /tmp/secret.key
unset PW1 PW2

echo "=== Stap 2: repo ophalen en vastpinnen ==="
rm -rf /tmp/werkplek
nix shell nixpkgs#git --command git clone --depth 1 "$REPO" /tmp/werkplek
nix shell nixpkgs#git --command nix flake lock /tmp/werkplek
FLAKE="/tmp/werkplek#$HOST"

echo "=== Stap 3: schijf loskoppelen en schoonmaken ==="
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

echo "=== Stap 4: partitioneren met disko ==="
nix shell nixpkgs#git --command \
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"

echo "=== Stap 5: Secure Boot-sleutels maken ==="
nix shell nixpkgs#sbctl --command sbctl create-keys
mkdir -p /mnt/var/lib
cp -a /var/lib/sbctl /mnt/var/lib/sbctl
chmod -R go-rwx /mnt/var/lib/sbctl

echo "=== Stap 6: installeren ==="
nix shell nixpkgs#git --command \
  nixos-install --flake "$FLAKE" --no-root-passwd

echo "=== Stap 7: wachtwoord klaarzetten voor TPM-inschrijving ==="
mkdir -p /mnt/var/lib/werkplek
install -m 600 /tmp/secret.key /mnt/var/lib/werkplek/luks-bootstrap.key

echo "=== Stap 8: Secure Boot-sleutels in de BIOS inschrijven ==="
if nix shell nixpkgs#sbctl --command sbctl enroll-keys --microsoft; then
  echo "Sleutels ingeschreven."
else
  echo "LET OP: inschrijven mislukt. Zet de BIOS in Setup Mode (Secure Boot-sleutels wissen)"
  echo "en voer na de herstart uit: sudo sbctl enroll-keys --microsoft"
fi

rm -f /tmp/secret.key
echo "=== Klaar, herstart ==="
echo "Zet daarna in de BIOS Secure Boot AAN als dat nog niet zo is."
reboot
