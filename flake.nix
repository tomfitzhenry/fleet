{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-25.11";
  };
  outputs = { nixpkgs-stable, ... }:
    let
      mkStableMachine = hostname: nixpkgs-stable.lib.nixosSystem {
        modules = [
	  ./hosts/${hostname}
	  { networking.hostName = hostname; }
          ./modules/common
        ];
      };
    in {
      nixosConfigurations = {
        oxygen = mkStableMachine "oxygen";
      };
    };
}
