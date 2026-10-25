# Instellingen die voor ALLE laptops van de organisatie gelden, ongeacht hardware.
# Gebruik hier altijd lib.mkDefault, zodat een host kan afwijken zonder foutmelding.
{ lib, ... }:
{
  # Laadt onze eigen bouwblokken (apps.nix definieert de schakelaars).
  imports = [ ./apps.nix ];

  # TPM2-unlock: de laptop ontgrendelt de schijf zelf via de TPM.
  # Het LUKS-wachtwoord blijft werken als terugval.
  dawo.diskUnlock.tpm2.enable = lib.mkDefault true;

  # EuroOffice standaard op elke laptop.
  # Een laptop die het niet wil: werkplek.apps.euroOffice.enable = false; in zijn hostbestand.
  werkplek.apps.euroOffice.enable = lib.mkDefault true;
}
