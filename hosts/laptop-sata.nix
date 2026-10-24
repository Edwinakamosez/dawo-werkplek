{ lib, ... }:
{
  networking.hostName = "laptop-sata";

  # DAWO's indeling wijst naar nvme0n1, dit is sda
  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  # SATA-driver in de initrd
  # boot.initrd.availableKernelModules = [ "ahci" "sd_mod" ]; zit al in nixos standaard

  dawo.desktop.plasma.enable = true;
  dawo.secureboot.enable = false;
  dawo.autoUpdate.enable = false;
  dawo.diskUnlock.tpm2.enable = true;  
}
