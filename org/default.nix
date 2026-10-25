# voeg in deze file de settings toe die voor de gehele organisatie gelden ongeacht hardware type

{ lib, ... }:
{
  # TPM2-unlock voor alle laptops (wachtwoord blijft als terugval)
  dawo.diskUnlock.tpm2.enable = lib.mkDefault true;
}
