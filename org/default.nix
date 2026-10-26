# Instellingen die voor ALLE laptops van de organisatie gelden, ongeacht hardware.
# Gebruik hier lib.mkDefault zodat een host kan afwijken zonder foutmelding.
{ lib, ... }:
{
  # Onze eigen bouwblokken: apps.nix.
 imports = [
    ./apps.nix
    ./Config-system-hostname.nix
  ];
  # --- Bureaublad ---
  # KDE Plasma voor iedereen. DAWO eist precies één van plasma of gnome.
  #dawo.desktop.plasma.enable = lib.mkDefault true; 
  #dawo.desktop.gnome.enable = lib.mkDefault true;

  dawo.desktop.plasma.enable = lib.mkDefault true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.enable = lib.mkForce false; #SDDM ondersteund geen MFA
  services.displayManager.gdm.enable = lib.mkForce true; #GDM ondersteund MFA
  dawo.pam.lockout.services = [ "login" "su" "sudo" "gdm-password" ]; #mitigerende maatregel tegen gat in security model van DAWO. door mixen van SDM en GDM in config.

  # Inlogscherm (GDM): geen lijst met gebruikers tonen. Entra-accounts staan er
  # toch niet in; wie inlogt typt zelf de gebruikersnaam (UPN). Het lokale
  # noodaccount "dawo" werkt nog steeds door het te typen.

  programs.dconf.profiles.gdm.databases = [
  { settings."org/gnome/login-screen".disable-user-list = true; }
  ];

  # --- Opstarten en schijf ---
  # Secure Boot (lanzaboote). De sleutels maakt install.sh aan.
  dawo.secureboot.enable = lib.mkDefault false;

  # TPM2-unlock: de laptop ontgrendelt de schijf zelf via de TPM.
  # Het LUKS-wachtwoord blijft werken als terugval.
  # De sleutel zelf schrijf je per laptop in met systemd-cryptenroll.
  # dawo.diskUnlock.tpm2.enable = lib.mkDefault true;

  # --- Updates ---
  # Zelfupdate via comin: uit tot er een eigen repo-koppeling is.
  # Prioriteit 900: sterker dan DAWO's eigen mkDefault (1000), die ook "aan" zegt,
  # maar zwakker dan een gewone waarde, zodat een host het kan overschrijven.
  # dawo.autoUpdate.enable = lib.mkOverride 900 false;

  dawo.autoUpdate.enable = lib.mkDefault true;
  dawo.autoUpdate.options.repoUrl = "https://github.com/Edwinakamosez/dawo-werkplek.git";

  # --- Standaard Programma's ---
  # EuroOffice op elke laptop. Een laptop die het niet wil:
  # werkplek.apps.euroOffice.enable = false; in zijn hostbestand.
  werkplek.apps.euroOffice.enable = lib.mkDefault true;
  werkplek.apps.nextcloud.enable = lib.mkDefault true;
}
