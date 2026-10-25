# Inloggen met Entra ID (Himmelblau), geldt voor alle laptops.
{ lib, himmelblau, ... }:
{
  imports = [ himmelblau.nixosModules.himmelblau ];

  services.himmelblau.enable = lib.mkDefault true;
  services.himmelblau.settings = {
    domain = "debruinonline.net";               # je Entra-domein
    #pam_allow_groups = [ "<object-id-van-entra-groep>" ]; # wie mag inloggen
  };
}
