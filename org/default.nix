# Instellingen die voor ALLE laptops van de organisatie gelden, ongeacht hardware.
# Gebruik hier lib.mkDefault zodat een host kan afwijken zonder foutmelding.
{ lib, ... }:
{
  # Onze eigen bouwblokken: apps.nix (programma's) en hostname.nix (willekeurige naam).
  imports = [ ./apps.nix ./hostname.nix ];
  #imports = [ ./apps.nix ]; #TEST MET HOSTNAME.NIX uit

  # --- Bureaublad ---
  # KDE Plasma voor iedereen. DAWO eist precies één van plasma of gnome.
  dawo.desktop.plasma.enable = lib.mkDefault true;

  # --- Opstarten en schijf ---
  # Secure Boot (lanzaboote). De sleutels maakt install.sh aan.
  dawo.secureboot.enable = lib.mkDefault true;

  # TPM2-unlock: de laptop ontgrendelt de schijf zelf via de TPM.
  # Het LUKS-wachtwoord blijft werken als terugval.
  # De sleutel zelf schrijf je per laptop in met systemd-cryptenroll.
  dawo.diskUnlock.tpm2.enable = lib.mkDefault true;

  # --- Updates ---
  # Zelfupdate via comin: uit tot er een eigen repo-koppeling is.
  # Prioriteit 900: sterker dan DAWO's eigen mkDefault (1000), die ook "aan" zegt,
  # maar zwakker dan een gewone waarde, zodat een host het kan overschrijven.
  dawo.autoUpdate.enable = lib.mkOverride 900 false;

  # --- Programma's ---
  # EuroOffice op elke laptop. Een laptop die het niet wil:
  # werkplek.apps.euroOffice.enable = false; in zijn hostbestand.
  werkplek.apps.euroOffice.enable = lib.mkDefault true;
}
