# A module for managing podman.
{ lib, config, ... }:
let
  cfg = config.tomf.podman;
in
{
  options = {
    tomf.podman = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
    users.users.podman = {
      uid = 1005;
      isNormalUser = true;
      extraGroups = [
        "render" # hw acceleration
      ];
      openssh.authorizedKeys.keys = config.users.users.tom.openssh.authorizedKeys.keys;

      # https://github.com/containers/podman/blob/main/troubleshooting.md#17-rootless-containers-exit-once-the-user-session-exits
      linger = true;

      # https://github.com/containers/podman/blob/main/troubleshooting.md#34-container-creates-a-file-that-is-not-owned-by-the-users-regular-uid
      autoSubUidGidRange = true;
    };
  };
}
