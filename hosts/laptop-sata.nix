# Instellingen die ALLEEN voor deze laptop gelden.
# Gewone waarden (zonder mkDefault) winnen van org en DAWO.
{ lib, ... }:
{
  networking.hostName = "laptop-sata";

  # DAWO's schijfindeling wijst naar /dev/nvme0n1. Deze laptop heeft een
  # SATA-schijf, dus overschrijven we het pad. mkForce = niet laten winnen door DAWO.
  # Let op: install.sh heeft ook DISK=/dev/sda, die twee moeten gelijk zijn.
  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  # ahci en sd_mod (SATA-drivers) zitten al in de NixOS-standaard, hier niets nodig.

  dawo.desktop.plasma.enable = true;   # KDE Plasma als bureaublad
  dawo.secureboot.enable = false;      # tijdelijk uit; later aan, daarna TPM inschrijven
  dawo.autoUpdate.enable = false;      # comin uit tot er een eigen repo-koppeling is
}
