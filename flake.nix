{
  inputs = {
    dawo.url = "git+https://codeberg.org/DAWO/DAWO-Core?ref=refs/tags/v0.2.0";
    himmelblau.url = "github:himmelblau-idm/himmelblau/main";
  };

  outputs = { dawo, himmelblau, ... }:
    let
      lib = dawo.inputs.nixpkgs.lib;

      # host = hardwaretype (hosts/<host>.nix), partner = map in Partners/<partner>
      mkHost = { host, partner }:
        let
          naam = "${host}-${lib.toLower partner}";
          args = { inputs = dawo.inputs; hostConfig.name = naam; inherit himmelblau; };
        in lib.nixosSystem {
          specialArgs = args;
          modules = [
            dawo.inputs.home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = args; }

            # Laag 1: DAWO
            dawo.modules.nixos.profiles-dawo-generic
            dawo.modules.nixos.boot-loader
            dawo.modules.nixos.hardware-generic-intel
            dawo.modules.nixos.disko-single-nvme-luks
            dawo.modules.nixos.maid-dawo-generic

            # Laag 2: organisatie
            ./org

            # Laag 3: hardwaretype
            ./hosts/${host}.nix

            # Laag 4: partner
            ./Partners/${partner}
          ];
        };
    in {
      nixosConfigurations = {
        laptop-sata-edwin = mkHost { host = "laptop-sata"; partner = "Edwin"; };
        laptop-nvme-edwin = mkHost { host = "laptop-nvme"; partner = "Edwin"; };
        laptop-sata-ruud  = mkHost { host = "laptop-sata"; partner = "Ruud"; };
        laptop-nvme-ruud  = mkHost { host = "laptop-nvme"; partner = "Ruud"; };
      };

      # USB-installer (zie installer/iso.nix). Bewust niet onder
      # nixosConfigurations, anders verschijnt hij in het menu van install.sh.
      packages.x86_64-linux.installer-iso =
        (lib.nixosSystem { modules = [ ./Installer/iso.nix ]; }).config.system.build.isoImage;
    };
}
