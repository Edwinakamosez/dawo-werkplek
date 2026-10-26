# Inloggen met Entra ID (Himmelblau), geldt voor alle laptops.
{ lib, himmelblau, ... }:
{
  imports = [ himmelblau.nixosModules.himmelblau ];

  services.himmelblau.enable = lib.mkDefault true;
  services.himmelblau.settings = {
    domain = [ "debruinonline.net" ];               # je Entra-domein
    app_id = "13f1fd0c-ae85-4a6a-935e-dbb8c5edae2e";
    #pam_allow_groups = [ "<object-id-van-entra-groep>" ]; # wie mag inloggen
  };

  # Inlogscherm (GDM): geen lijst met gebruikers tonen. Entra-accounts staan er
  # toch niet in; wie inlogt typt zelf de gebruikersnaam (UPN). Het lokale
  # noodaccount "dawo" werkt nog steeds door het te typen.
  programs.dconf.profiles.gdm.databases = [
    { settings."org/gnome/login-screen".disable-user-list = true; }
  ];
}
