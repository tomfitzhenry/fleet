{
  inputs = {
    nixpkgs-2605.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    comin-2605 = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };
    microvm-2605 = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-2605";
    };
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
  };
  outputs =
    inputs@{
      self,
      comin-2605,
      hercules-ci-effects,
      microvm-2605,
      nixpkgs-2605,
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
            ./modules/op-tee
            ./modules/otel-collector
            ./modules/podman
            ./modules/remote-builders
            ./modules/rootfs
            ./modules/sshd
            ./modules/wireguard
          ];
        };
      mkMachine_2605 = mkMachine nixpkgs-2605 comin-2605 microvm-2605;
    in
    {
      nixosConfigurations = {
        argon = mkMachine_2605 "argon";
        oxygen = mkMachine_2605 "oxygen";
        strontium = mkMachine_2605 "strontium";
        aluminium = mkMachine_2605 "aluminium";
        platinum = mkMachine_2605 "platinum";
        rockpro64 = mkMachine_2605 "rockpro64";
        redbox = mkMachine_2605 "redbox";
        cam = mkMachine_2605 "cam";
      };

      checks.x86_64-linux = {
        rootfs = nixpkgs-2605.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./modules/rootfs/vm-test.nix
        );
        step-ca = nixpkgs-2605.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./modules/step-ca/vm-test.nix
        );
        mail-relay = nixpkgs-2605.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./modules/mail-relay/vm-test.nix
        );
      };

      herculesCI = hercules-ci-effects.lib.mkHerculesCI { inherit inputs; } {
        herculesCI.ciSystems = [
          "aarch64-linux"
          "armv7l-linux"
          "x86_64-linux"
        ];
      };
    };
}
