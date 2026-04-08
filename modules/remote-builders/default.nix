# A module for enabling remote builders from nix-community.org
# https://nix-community.org/community-builders/
{ lib, config, ... }:
let
  cfg = config.tomf.remote-builders;
in
{
  options = {
    tomf.remote-builders = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable remote builders from nix-community.org";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    nix.distributedBuilds = true;

    nix.settings.builders-use-substitutes = true;

    nix.buildMachines = [
      {
        hostName = "build-box.nix-community.org";
        systems = [ "x86_64-linux" ];
        sshUser = "tomfitzhenry";
        sshKey = "/etc/ssh/nix-community-builder";
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
      }
      {
        hostName = "aarch64-build-box.nix-community.org";
        systems = [ "aarch64-linux" ];
        sshUser = "tomfitzhenry";
        sshKey = "/etc/ssh/nix-community-builder";
        maxJobs = 16;
        speedFactor = 1;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
      }
    ];
  };
}
