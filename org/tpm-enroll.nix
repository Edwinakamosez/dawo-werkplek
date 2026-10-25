# Schrijft de TPM2 automatisch in zodra Secure Boot actief is.
# Gebruikt het tijdelijke wachtwoordbestand dat install.sh heeft neergezet en
# verwijdert het daarna. Het wachtwoord zelf blijft werken als noodtoegang.
{ pkgs, ... }:
let
  keyFile = "/var/lib/werkplek/luks-bootstrap.key";
  device = "/dev/disk/by-partlabel/disk-main-luks";
in
{
  systemd.services.werkplek-tpm-enroll = {
    description = "TPM2-unlock automatisch inschrijven";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    unitConfig = {
      ConditionPathExists = [ keyFile "/dev/tpmrm0" ];
    };
    serviceConfig.Type = "oneshot";
    path = [ pkgs.systemd pkgs.coreutils ];
    script = ''
      sb=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
      if [ ! -e "$sb" ] || [ "$(od -An -t u1 -j4 -N1 "$sb" | tr -d ' ')" != "1" ]; then
        echo "Secure Boot nog niet actief, TPM-inschrijving volgende start opnieuw."
        exit 0
      fi
      systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 \
        --unlock-key-file=${keyFile} ${device}
      shred -u ${keyFile}
      echo "TPM2 ingeschreven."
    '';
  };
}
