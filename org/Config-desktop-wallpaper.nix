# Eigen achtergrond per partner, in plaats van de DAWO-achtergrond.
# DAWO zet zijn achtergrond via nix-maid (maid-dawo-generic) voor alle
# gebruikers, ook Entra-accounts. Wij overschrijven precies die waarden met
# mkForce: bureaublad, vergrendelscherm en de lijst in de achtergrondkiezer.
#
# Gebruik in Partners/<naam>/default.nix:
#   werkplek.wallpaper = ./mijn-achtergrond.png;
{ config, lib, ... }:
let
  wallpaper = config.werkplek.wallpaper;
  image = "${wallpaper}";

  # DAWO maakt bureaubladen 1 t/m 5 aan (één per scherm); die overschrijven we alle vijf.
  desktops = builtins.listToAttrs (
    map (n: {
      name = toString n;
      value.Wallpaper."org.kde.image".General.Image = lib.mkForce image;
    }) [ 1 2 3 4 5 ]
  );
in
{
  options.werkplek.wallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Achtergrond voor bureaublad en vergrendelscherm (Plasma). null = DAWO-standaard.";
  };

  config = lib.mkIf (wallpaper != null && config.dawo.desktop.plasma.enable) {
    maid.sharedModules = [
      {
        kconfig.settings = {
          "plasma-org.kde.plasma.desktop-appletsrc".Containments = desktops;
          kscreenlockerrc.Greeter.Wallpaper."org.kde.image".General.Image = lib.mkForce image;
          plasmarc.Wallpapers.usersWallpapers = lib.mkForce image;
        };
      }
    ];
  };
}
