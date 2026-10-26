# Willekeurige hostnaam met vaste prefix, eenmalig gekozen bij de eerste start.
# Voorbeeld: dawo-3fa91c07. De naam blijft daarna staan, ook na een herstart.
{ lib, pkgs, hostConfig, ... }:
let
  # Pas aan naar de prefix van jullie organisatie.
  prefix = "DBO";
in
{
  # Leeg laten: NixOS schrijft dan zelf geen /etc/hostname, dus onze service mag dat doen.
  networking.hostName = lib.mkDefault "";

  systemd.services.werkplek-hostname = {
    description = "Willekeurige hostnaam bij de eerste start";
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

    path = [ pkgs.coreutils ];
    script = ''
      name="${prefix}-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

      # Vastleggen voor volgende starts (systemd leest /etc/hostname bij het opstarten)
      echo "$name" > /etc/hostname
      # En meteen actief maken
      echo "$name" > /proc/sys/kernel/hostname
      # Onthouden dat we klaar zijn
      echo "$name" > /var/lib/werkplek/hostname
    '';
  };

  # comin kiest de configuratie op hostnaam. Met een willekeurige naam bestaat die
  # niet in de flake, dus wijzen we hem naar de vaste buildnaam (laptop-sata).
  services.comin.hostname = lib.mkDefault hostConfig.name;

  # Liever een stabiele naam op basis van het serienummer? Vervang dan de name=-regel door:
  #   name="${prefix}-$(tr -d ' ' < /sys/class/dmi/id/product_serial | tail -c 7 | tr 'A-Z' 'a-z')"
}
