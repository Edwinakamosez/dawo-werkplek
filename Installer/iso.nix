# USB-installer: een gewone NixOS-stick die na het opstarten zelf het
# installatiecommando uitvoert. Er staat niets van de repo op; het script
# komt elke keer vers van GitHub.
#
# Bouwen (op een Linux-machine met Nix):
#   nix build github:Edwinakamosez/dawo-werkplek#installer-iso
# Het ISO-bestand staat daarna in result/iso/.
{ lib, pkgs, modulesPath, ... }:
let
  url = "https://raw.githubusercontent.com/Edwinakamosez/dawo-werkplek/main/install.sh";

  dawo-install = pkgs.writeShellScriptBin "dawo-install" ''
    # Wachten op internet; zonder kabel opent het wifi-menu.
    until ${pkgs.curl}/bin/curl -sfI https://github.com >/dev/null; do
      echo "Geen internet. Kies een wifi-netwerk in het menu (of sluit een kabel aan)."
      sleep 2
      ${pkgs.networkmanager}/bin/nmtui connect || true
    done
    ${pkgs.curl}/bin/curl -sL ${url} | bash -s -- "$@"
  '';
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NetworkManager (nmtui) voor wifi, in plaats van kale wpa_supplicant.
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager.enable = true;

  environment.systemPackages = [ dawo-install ];

  # De installer logt op tty1 automatisch in als "nixos"; daar starten we het
  # commando één keer. Op andere schermen (Alt+F2) krijg je gewoon een shell.
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ ! -e /tmp/dawo-install-gestart ]; then
      touch /tmp/dawo-install-gestart
      sudo dawo-install || echo "Installatie gestopt. Opnieuw starten: sudo dawo-install"
    fi
  '';
}
