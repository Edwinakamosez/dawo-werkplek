# Inloggen met Entra ID (Himmelblau), geldt voor alle laptops.
{ lib, himmelblau, ... }:
{
  imports = [ himmelblau.nixosModules.himmelblau ];

  services.himmelblau.enable = lib.mkDefault true;
  services.himmelblau.settings = {
    domain = [ "debruinonline.net" ];               # je Entra-domein
    app_id = "13f1fd0c-ae85-4a6a-935e-dbb8c5edae2e";
    mfa_method = "PhoneAppOTP";                     # zescijferige code uit de Authenticator-app, geen nummer-melding
    #pam_allow_groups = [ "<object-id-van-entra-groep>" ]; # wie mag inloggen
  };
}
