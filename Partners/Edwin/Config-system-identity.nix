# Inloggen met Entra ID (Himmelblau), geldt voor alle laptops.
{ lib, himmelblau, ... }:
{
  imports = [ himmelblau.nixosModules.himmelblau ];

  services.himmelblau.enable = lib.mkDefault true;

  # Standaardlijst van Himmelblau + "kde": het KDE-vergrendelscherm gebruikt
  # PAM-service "kde", zonder deze werkt ontgrendelen met Entra niet.

  services.himmelblau.pamServices = [ "passwd" "login" "su" "systemd-user" "kde" ];

  services.himmelblau.settings = {
    oidc_issuer_url = "https://lemur-8.cloud-iam.com/auth/realms/debruinonlinenet"; #Keycloak
    app_id = "NixOS-Werkplek"; #Keycloak
    allow_console_password_only = false; #Keycloak
    
    #domain = [ "debruinonline.net" ];               # je Entra-domein
    #app_id = "13f1fd0c-ae85-4a6a-935e-dbb8c5edae2e";
    #pam_allow_groups = [ "<object-id-van-entra-groep>" ]; # wie mag inloggen
    shell = "/run/current-system/sw/bin/bash";
  };
}
