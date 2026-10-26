{ ... }:
{
  environment.etc."Nextcloud/nextcloud.cfg".text = ''
    [General]
    overrideServerUrl=https://nextclouddummynoginvullen
    forceLoginV2=true #forceer naar browserlogin
  '';
}
