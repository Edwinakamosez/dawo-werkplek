{
  inputs.dawo.url = "git+https://codeberg.org/DAWO/DAWO-Core?ref=refs/tags/v0.2.0";

  outputs = { dawo, ... }:
    let
      args = { inputs = dawo.inputs; hostConfig.name = "laptop-sata"; };
    in {
      nixosConfigurations.laptop-sata = dawo.inputs.nixpkgs.lib.nixosSystem {
        specialArgs = args;
        modules = [
          dawo.inputs.home-manager.nixosModules.home-manager
          { home-manager.extraSpecialArgs = args; }
          dawo.modules.nixos.profiles-dawo-generic
          dawo.modules.nixos.boot-loader
          dawo.modules.nixos.hardware-generic-intel
          dawo.modules.nixos.disko-single-nvme-luks
          dawo.modules.nixos.maid-dawo-generic
          ./hosts/laptop-sata.nix
        ];
      };
    };
}
