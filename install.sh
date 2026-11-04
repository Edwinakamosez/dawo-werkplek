#!/usr/bin/env bash
set -euo pipefail
export NIX_CONFIG="experimental-features = nix-command flakes"

REPO=https://github.com/Edwinakamosez/dawo-werkplek.git
HOST="${1:-}"

[ "$(id -u)" -eq 0 ] || { echo "Draai dit als root: sudo bash /tmp/install.sh"; exit 1; }
cd /tmp

# De live-USB draait uit het RAM; met te weinig geheugen loopt de installatie vast.
MEM_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
if [ "$MEM_GB" -lt 6 ]; then
  echo "WAARSCHUWING: deze machine heeft ${MEM_GB} GB geheugen; minimaal 8 GB wordt aangeraden."
  read -r -p "Toch doorgaan? (j/n) " DOOR </dev/tty
  [ "$DOOR" = "j" ] || { echo "Afgebroken."; exit 1; }
fi

echo "=== Stap 1: repo ophalen en vastpinnen ==="
rm -rf /tmp/werkplek
nix shell nixpkgs#git --command git clone --depth 1 "$REPO" /tmp/werkplek

# --- Apparaatregister (devices.json): herken deze laptop aan het serienummer ---
# De sleutel is een sha256 van "serial:<serienummer>" (kleine letters, zonder spaties),
# of "uuid:<uuid>" als het serienummer ontbreekt of een placeholder is.
# Dezelfde berekening staat in org/Config-system-hostname.nix (werkplek-device-id).
DMI_DIR="${DMI_DIR:-/sys/class/dmi/id}"
read_dmi() { { cat "$DMI_DIR/$1" 2>/dev/null || true; } | tr -d '\n' | sed 's/^ *//; s/ *$//'; }
SERIAL="$(read_dmi product_serial | tr 'A-Z' 'a-z' | tr -d ' ')"
UUID_HW="$(read_dmi product_uuid | tr 'A-Z' 'a-z')"
case "$SERIAL" in
  ""|"defaultstring"|"tobefilledbyo.e.m."|"none"|"n/a"|"0"|"systemserialnumber"|"notspecified"|"unknown")
    DEVICE_KEY="uuid:$UUID_HW" ;;
  *) DEVICE_KEY="serial:$SERIAL" ;;
esac
DEVICE_ID="$(printf '%s' "$DEVICE_KEY" | sha256sum | cut -d' ' -f1)"
echo "Apparaat: $DEVICE_KEY"
echo "Apparaat-ID: $DEVICE_ID"

DEV_HOST=""; DEV_PARTNER=""; DEV_BRANCH=""; DEV_NAME=""
if [ -f /tmp/werkplek/devices.json ]; then
  IFS='|' read -r DEV_HOST DEV_PARTNER DEV_BRANCH DEV_NAME < <(
    nix shell nixpkgs#jq --command jq -r --arg id "$DEVICE_ID" \
      '.devices[$id] // empty | [(.host // ""), (.partner // ""), (.branch // "main"), (.name // "")] | join("|")' \
      /tmp/werkplek/devices.json 2>/dev/null || true
  ) || true
fi

if [ -n "$DEV_HOST" ] && [ -n "$DEV_PARTNER" ]; then
  # Alleen veilige waarden toestaan (komen uit een bestand in de repo).
  [[ "$DEV_HOST" =~ ^[a-z0-9-]+$ ]] || { echo "FOUT: ongeldige host in devices.json."; exit 1; }
  [[ "$DEV_PARTNER" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "FOUT: ongeldige partner in devices.json."; exit 1; }
  [[ "$DEV_BRANCH" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || DEV_BRANCH=main
  if [ -z "$HOST" ]; then
    HOST="$DEV_HOST-$(printf '%s' "$DEV_PARTNER" | tr 'A-Z' 'a-z')"
    echo "=== Apparaat herkend in devices.json ==="
    echo "Naam: ${DEV_NAME:-(willekeurig)}   Configuratie: $HOST   Branch: $DEV_BRANCH"
    if [ "$DEV_BRANCH" != "main" ]; then
      echo "Andere branch gevraagd: repo opnieuw ophalen van $DEV_BRANCH."
      rm -rf /tmp/werkplek
      nix shell nixpkgs#git --command git clone --depth 1 --branch "$DEV_BRANCH" "$REPO" /tmp/werkplek
    fi
  else
    echo "Hostnaam is op de opdrachtregel meegegeven; devices.json wordt genegeerd."
  fi
else
  echo "Dit apparaat staat niet in devices.json. Je kiest het type zelf."
  echo "Wil je het vooraf registreren? Zet dit Apparaat-ID in devices.json."
fi

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

# De live-USB draait uit het RAM; zet de swapfile die disko net heeft
# aangemaakt aan, anders loopt het geheugen vol tijdens het bouwen.
swapon /mnt/.swapvol/swapfile || echo "WAARSCHUWING: swap aanzetten mislukt."

echo "=== Stap 5: installeren ==="
# Niet te veel tegelijk bouwen: Himmelblau compileert Rust en dat vraagt veel geheugen.
nix shell nixpkgs#git --command \
  nixos-install --flake "$FLAKE" --no-root-passwd --max-jobs 2

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
echo "=== Klaar ==="
# Anders start de laptop weer van de stick en begint de installatie opnieuw.
read -r -p "Haal de USB-stick eruit en druk op Enter om te herstarten. " _ </dev/tty
reboot
