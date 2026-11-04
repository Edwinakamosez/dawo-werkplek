# Hostnaam van de laptop.
# 1. Staat dit apparaat in devices.json (op serienummer) met een "name"? Dan wordt dat de naam.
# 2. Anders: willekeurige hostnaam met vaste prefix, eenmalig gekozen bij de eerste start.
#    Voorbeeld: DBO-3fa91c07.
# De naam blijft daarna staan, ook na een herstart.
#
# Het apparaat-ID is een sha256 van "serial:<serienummer>" (kleine letters, zonder spaties),
# of "uuid:<uuid>" als het serienummer ontbreekt of een placeholder is.
# Dezelfde berekening staat in install.sh. Pas je het aan, pas het dan op beide plekken aan.
{ lib, pkgs, hostConfig, ... }:
let
  # Pas aan naar de prefix van jullie organisatie.
  prefix = "DBO";

  # Hulpprogramma: `werkplek-device-id` toont het apparaat-ID; met --show ook de sleutel.
  deviceId = pkgs.writeShellApplication {
    name = "werkplek-device-id";
    runtimeInputs = [ pkgs.coreutils pkgs.gnused ];
    text = ''
      dmi=/sys/class/dmi/id
      read_dmi() { { cat "$dmi/$1" 2>/dev/null || true; } | tr -d '\n' | sed 's/^ *//; s/ *$//'; }
      serial=$(read_dmi product_serial | tr 'A-Z' 'a-z' | tr -d ' ')
      uuid=$(read_dmi product_uuid | tr 'A-Z' 'a-z')
      case "$serial" in
        ""|"defaultstring"|"tobefilledbyo.e.m."|"none"|"n/a"|"0"|"systemserialnumber"|"notspecified"|"unknown")
          key="uuid:$uuid" ;;
        *) key="serial:$serial" ;;
      esac
      id=$(printf '%s' "$key" | sha256sum | cut -d' ' -f1)
      if [ "''${1:-}" = "--show" ]; then
        echo "key=$key"
      fi
      echo "$id"
    '';
  };
in
{
  environment.systemPackages = [ deviceId ];

  # Het register zelf (alleen lezen) op de laptop; komt mee met elke update.
  environment.etc."werkplek/devices.json".source = ../devices.json;

  # Leeg laten: NixOS schrijft dan zelf geen /etc/hostname, dus onze service mag dat doen.
  networking.hostName = lib.mkDefault "";

  systemd.services.werkplek-hostname = {
    description = "Hostnaam uit het apparaatregister of willekeurig bij de eerste start";
    wantedBy = [ "multi-user.target" ];
    before = [ "network-pre.target" ];
    wants = [ "network-pre.target" ];

    # Draait maar één keer: zodra dit bestand bestaat, slaat hij over.
    unitConfig.ConditionPathExists = "!/var/lib/werkplek/hostname";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "werkplek";
    };

    path = [ pkgs.coreutils pkgs.jq pkgs.gnugrep deviceId ];
    script = ''
      name=""
      reg=/etc/werkplek/devices.json
      id=$(werkplek-device-id || true)

      # Naam uit het register, alleen als het een geldige hostnaam is.
      if [ -r "$reg" ] && [ -n "$id" ]; then
        name=$(jq -r --arg id "$id" '.devices[$id].name // empty' "$reg" 2>/dev/null || true)
        if ! printf '%s' "$name" | grep -qE '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'; then
          name=""
        fi
      fi

      # Geen (geldige) naam in het register: willekeurig met vaste prefix.
      if [ -z "$name" ]; then
        name="${prefix}-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      fi

      # Vastleggen voor volgende starts (systemd leest /etc/hostname bij het opstarten)
      echo "$name" > /etc/hostname
      # En meteen actief maken
      echo "$name" > /proc/sys/kernel/hostname
      # Onthouden dat we klaar zijn
      echo "$name" > /var/lib/werkplek/hostname
    '';
  };

  # comin kiest de configuratie op hostnaam. Met een willekeurige naam bestaat die
  # niet in de flake, dus wijzen we hem naar de vaste buildnaam (bijv. laptop-sata-edwin).
  services.comin.hostname = lib.mkDefault hostConfig.name;

  # Liever een stabiele naam op basis van het serienummer zonder register? Vervang dan de name=-regel door:
  #   name="${prefix}-$(tr -d ' ' < /sys/class/dmi/id/product_serial | tail -c 7 | tr 'A-Z' 'a-z')"
}
