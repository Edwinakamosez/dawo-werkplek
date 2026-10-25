{
  # NIEUW: inputs is nu een blok, want er zijn er twee.
  inputs = {
    # De basis: DAWO-Core, vastgepind op een versie (tag).
    # DAWO updaten = hier het versienummer wijzigen, bijvoorbeeld v0.2.0 -> v0.3.0.
    dawo.url = "git+https://codeberg.org/DAWO/DAWO-Core?ref=refs/tags/v0.2.0";

    # Entra ID-login op de laptop (Himmelblau). Wordt gebruikt in org/identity.nix.
    himmelblau.url = "github:himmelblau-idm/himmelblau/main";
  };

  # NIEUW: himmelblau erbij in de argumenten
  outputs = { dawo, himmelblau, ... }:
    let
      # Gegevens die DAWO-blokken verwachten. "inputs" is nodig voor o.a.
      # hardware-generic-intel; hostConfig.name is de naam van deze laptop.
      # NIEUW: himmelblau doorgeven, zodat org/identity.nix de module kan laden.
      args = { inputs = dawo.inputs; hostConfig.name = "laptop-sata"; inherit himmelblau; };
    in {
      # Eén laptop-configuratie. install.sh wijst hiernaar met #laptop-sata.
      nixosConfigurations.laptop-sata = dawo.inputs.nixpkgs.lib.nixosSystem {
        specialArgs = args;

        # Alles wat in het systeem komt. De volgorde doet er niet toe,
        # wie wint bij een conflict bepaalt de prioriteit (mkDefault / gewoon / mkForce).
        modules = [
          # --- Techniek die DAWO nodig heeft ---
          dawo.inputs.home-manager.nixosModules.home-manager
          { home-manager.extraSpecialArgs = args; }

          # --- Laag 1: DAWO-blokken ---
          dawo.modules.nixos.profiles-dawo-generic      # beveiliging, Plasma, apps, gebruiker
          dawo.modules.nixos.boot-loader                # opstarten (systemd-boot)
          dawo.modules.nixos.hardware-generic-intel     # Intel-hardware en firmware
          dawo.modules.nixos.disko-single-nvme-luks     # schijfindeling met LUKS (pad overschrijven we in de host)
          dawo.modules.nixos.maid-dawo-generic          # gebruikersomgeving

          # --- Laag 2: onze organisatie, geldt voor alle laptops ---
          ./org

          # --- Laag 3: alleen deze laptop ---
          ./hosts/laptop-sata.nix
        ];
      };
    };
}
