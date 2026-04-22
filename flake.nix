{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };
  outputs =
    { comin, nixpkgs-stable, ... }:
    let
      mkStableMachine =
        hostname:
        nixpkgs-stable.lib.nixosSystem {
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
            ./modules/tlshd
            ./modules/wireguard
          ];
        };
    in
    {
      nixosConfigurations = {
        oxygen = mkStableMachine "oxygen";
        aluminium = mkStableMachine "aluminium";
        platinum = mkStableMachine "platinum";
        redbox = mkStableMachine "redbox";
        rockpro64 = mkStableMachine "rockpro64";
      };

      checks.x86_64-linux = {
        # Disabled until CI can run this.
        rootfs = nixpkgs-stable.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./modules/rootfs/vm-test.nix
        );
        oxygen = nixpkgs-stable.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./hosts/oxygen/vm-test.nix
        );
        redbox = nixpkgs-stable.legacyPackages.x86_64-linux.testers.nixosTest (
          import ./hosts/redbox/vm-test.nix
        );
      };
    };
}
