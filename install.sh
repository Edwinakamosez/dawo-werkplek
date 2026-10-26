#!/usr/bin/env bash
set -euo pipefail
export NIX_CONFIG="experimental-features = nix-command flakes"

REPO=https://github.com/Edwinakamosez/dawo-werkplek.git
HOST="${1:-}"

[ "$(id -u)" -eq 0 ] || { echo "Draai dit als root: sudo bash /tmp/install.sh"; exit 1; }
cd /tmp

echo "=== Stap 1: repo ophalen en vastpinnen ==="
rm -rf /tmp/werkplek
nix shell nixpkgs#git --command git clone --depth 1 "$REPO" /tmp/werkplek
nix shell nixpkgs#git --command nix flake lock /tmp/werkplek

# Geen hostnaam meegegeven? Toon een menu met alle hosts uit de flake.
if [ -z "$HOST" ]; then
  mapfile -t HOSTS < <(nix shell nixpkgs#git --command \
    nix eval --raw "/tmp/werkplek#nixosConfigurations" \
    --apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x)')
  [ "${#HOSTS[@]}" -gt 0 ] || { echo "FOUT: geen hosts gevonden in de flake."; exit 1; }
  # Suggestie op basis van de aanwezige schijf (alleen een hint, jij kiest)
  SUGGESTIE=""
  if ls /dev/nvme0n1 >/dev/null 2>&1; then SUGGESTIE="laptop-nvme"; elif ls /dev/sda >/dev/null 2>&1; then SUGGESTIE="laptop-sata"; fi
  echo "Kies het type laptop:"
  for i in "${!HOSTS[@]}"; do
    mark=""; [[ "${HOSTS[$i]}" == "$SUGGESTIE"* ]] && mark="   <- gedetecteerd"
    echo "  $((i+1))) ${HOSTS[$i]}$mark"
  done
  read -r -p "Nummer: " KEUZE </dev/tty
  [[ "$KEUZE" =~ ^[0-9]+$ ]] && [ "$KEUZE" -ge 1 ] && [ "$KEUZE" -le "${#HOSTS[@]}" ] \
    || { echo "Ongeldige keuze."; exit 1; }
  HOST="${HOSTS[$((KEUZE-1))]}"
fi
FLAKE="/tmp/werkplek#$HOST"

# Het schijfpad staat maar op één plek: in de hostconfiguratie van de flake.
DISK=$(nix shell nixpkgs#git --command \
  nix eval --raw "/tmp/werkplek#nixosConfigurations.$HOST.config.disko.devices.disk.main.device") \
  || { echo "FOUT: host '$HOST' niet gevonden in de flake."; exit 1; }
[ -b "$DISK" ] || { echo "FOUT: $DISK bestaat niet op deze machine (host '$HOST' klopt niet bij deze hardware?)."; exit 1; }
[ "$(lsblk -ndo TRAN "$DISK")" != "usb" ] || { echo "FOUT: $DISK is USB. Gestopt."; exit 1; }

echo "=== DAWO installatie van '$HOST': dit WIST $DISK volledig ==="
lsblk "$DISK"
read -r -p "Typ JA om door te gaan: " ANTWOORD </dev/tty
[ "$ANTWOORD" = "JA" ] || { echo "Afgebroken."; exit 1; }

echo "=== Stap 2: LUKS-wachtwoord kiezen ==="
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

echo "=== Stap 3: schijf loskoppelen en schoonmaken ==="
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
for m in $(lsblk -nrpo NAME,TYPE "$DISK" | awk '$2=="crypt"{print $1}'); do
  cryptsetup close "$m" || true
done
# Eerst elke partitie wissen (daar zit het LUKS-kopstuk), daarna de schijf zelf
for p in $(lsblk -lnpo NAME "$DISK" | tail -n +2); do
  wipefs -af "$p"
  dd if=/dev/zero of="$p" bs=1M count=16 conv=fsync
done
wipefs -af "$DISK"
nix shell nixpkgs#gptfdisk --command sgdisk --zap-all "$DISK"
dd if=/dev/zero of="$DISK" bs=1M count=20 conv=fsync
partprobe "$DISK" || true
udevadm settle

echo "=== Stap 4: partitioneren met disko ==="
nix shell nixpkgs#git --command \
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"

echo "=== Stap 5: installeren ==="
nix shell nixpkgs#git --command \
  nixos-install --flake "$FLAKE" --no-root-passwd

echo "=== Stap 6: TPM2 automatisch inschrijven ==="
if [ -e /dev/tpmrm0 ]; then
  udevadm settle
  if systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
       --unlock-key-file=/tmp/secret.key \
       /dev/disk/by-partlabel/disk-main-luks; then
    echo "TPM2 ingeschreven: de schijf ontgrendelt zichzelf bij de eerste start."
  else
    echo "WAARSCHUWING: TPM-inschrijving mislukt. De laptop vraagt gewoon het wachtwoord."
  fi
else
  echo "Geen TPM gevonden, overgeslagen. De laptop vraagt het wachtwoord."
fi

rm -f /tmp/secret.key
echo "=== Klaar, herstart ==="
reboot
