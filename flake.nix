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

            ./modules/common
            ./modules/rootfs
            ./modules/sshd
          ];
        };
    in
    {
      nixosConfigurations = {
        oxygen = mkStableMachine "oxygen";
        aluminium = mkStableMachine "aluminium";
	redbox = mkStableMachine "redbox";
      };
    };
}
