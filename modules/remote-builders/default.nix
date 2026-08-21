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

    # Advertise the gccarch features that arm builds request, so the
    # nix-daemon (and any hercules-ci-agent using it) dispatches them to the remote
    # aarch64 builders.
    nix.settings.extra-system-features = [
      "gccarch-armv7-a"
      "gccarch-armv8-a"
    ];

    nix.buildMachines = [
      {
        hostName = "build-box.nix-community.org";
        systems = [ "x86_64-linux" ];
        sshUser = "tomfitzhenry";
        sshKey = "/etc/ssh/nix-community-builder";
        maxJobs = 4;
        speedFactor = 4;
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
        systems = [
          "aarch64-linux"
          "armv7l-linux"
        ];
        sshUser = "tomfitzhenry";
        sshKey = "/etc/ssh/nix-community-builder";
        maxJobs = 16;
        speedFactor = 4;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "gccarch-armv7-a"
          "gccarch-armv8-a"
          "kvm"
          "nixos-test"
          "uid-range"
        ];
        mandatoryFeatures = [ ];
      }
    ];
  };
}
