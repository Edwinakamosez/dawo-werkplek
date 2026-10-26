# Inloggen met Entra ID (Himmelblau), geldt voor alle laptops.
{ lib, himmelblau, ... }:
{
  imports = [ himmelblau.nixosModules.himmelblau ];

  services.himmelblau.enable = lib.mkDefault true;
  services.himmelblau.settings = {
    domain = [ "ruudb.it" ];               # je Entra-domein
    app_id = "29ad6551-162d-4eec-a100-421e0d6ffed6";
    #pam_allow_groups = [ "<object-id-van-entra-groep>" ]; # wie mag inloggen
  };
}
