{
  inputs = {
    nixpkgs-2511.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    nixpkgs-2605.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    comin-2511 = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs-2511";
    };
    comin-2605 = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };
    microvm-2511 = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-2511";
    };
    microvm-2605 = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };
  };
  outputs =
    {
      comin-2511,
      comin-2605,
      microvm-2511,
      microvm-2605,
      nixpkgs-2511,
      nixpkgs-2605,
      ...
    }:
    let
      mkMachine =
        nixpkgs: comin: microvm: hostname:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit microvm; };
          modules = [
            ./hosts/${hostname}
            { networking.hostName = hostname; }

            comin.nixosModules.comin

            ./modules/comin
            ./modules/common
            ./modules/nfs-client
            ./modules/podman
            ./modules/remote-builders
            ./modules/rootfs
            ./modules/sshd
            ./modules/wireguard
          ];
        };
      mkMachine_2511 = mkMachine nixpkgs-2511 comin-2511 microvm-2511;
      mkMachine_2605 = mkMachine nixpkgs-2605 comin-2605 microvm-2605;
    in
    {
      nixosConfigurations = {
        argon = mkMachine_2605 "argon";
        oxygen = mkMachine_2605 "oxygen";

        strontium = mkMachine_2511 "strontium";
        aluminium = mkMachine_2511 "aluminium";
        platinum = mkMachine_2511 "platinum";
        redbox = mkMachine_2511 "redbox";
        rockpro64 = mkMachine_2511 "rockpro64";
      };

      checks.x86_64-linux = {
        # Disabled until CI can run this.
        rootfs = nixpkgs-2511.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./modules/rootfs/vm-test.nix
        );
        oxygen = nixpkgs-2511.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./hosts/oxygen/vm-test.nix
        );
      };
    };
}
