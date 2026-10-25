# Eigen bouwblok voor programma's die niet in DAWO's appsets zitten.
# Elk programma krijgt een eigen aan/uit-schakelaar onder "werkplek.apps.*",
# zodat de naam nooit botst met DAWO's eigen "dawo.*" opties.
{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.werkplek.apps.euroOffice;

  # EuroOffice zit nog niet in nixpkgs 26.05, dus pakken we het uit de
  # unstable-input die DAWO al meebrengt. Zodra het in 26.11 zit kan dit weg.
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # De schakelaar zelf. Standaard uit; org/default.nix zet hem aan.
  options.werkplek.apps.euroOffice.enable =
    lib.mkEnableOption "EuroOffice desktop editors (uit nixpkgs-unstable)";
    nextcloud.enable  = lib.mkEnableOption "Nextcloud-synchronisatieclient";

  # Alleen als de schakelaar aan staat, wordt het pakket geïnstalleerd.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ unstable.euro-office-desktopeditors ];
    ++ lib.optional cfg.nextcloud.enable pkgs.nextcloud-client;
  };
}
