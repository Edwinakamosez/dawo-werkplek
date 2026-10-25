# Instellingen die voor ALLE laptops van de organisatie gelden, ongeacht hardware.
# Gebruik hier altijd lib.mkDefault, zodat een host kan afwijken zonder foutmelding.
{ lib, ... }:
{
  # TPM2-unlock: de laptop ontgrendelt de schijf zelf via de TPM.
  # Het LUKS-wachtwoord blijft werken als terugval.
  # De sleutel zelf schrijf je per laptop in met systemd-cryptenroll.
  dawo.diskUnlock.tpm2.enable = lib.mkDefault true;
}
