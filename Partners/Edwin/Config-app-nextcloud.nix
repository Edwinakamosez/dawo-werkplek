{ ... }:
{
  environment.etc."Nextcloud/nextcloud.cfg".text = ''
    [General]
    overrideServerUrl=https://fie.nl.tab.digital/
    forceLoginV2=true #forceer naar browserlogin
  '';
}
