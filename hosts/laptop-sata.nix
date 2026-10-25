# Instellingen die ALLEEN voor deze laptop gelden.
# Gewone waarden (zonder mkDefault) winnen van org en DAWO.
{ lib, ... }:
{
  # DAWO's schijfindeling wijst naar /dev/nvme0n1. Deze laptop heeft een
  # SATA-schijf, dus overschrijven we het pad. mkForce = niet laten winnen door DAWO.
  # Let op: install.sh heeft ook DISK=/dev/sda, die twee moeten gelijk zijn.

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";
}
