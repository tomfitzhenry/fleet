# Optiplex 7070 Micro, a VM/container host.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-enc";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

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

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  fileSystems."/mnt/share" = {
    device = "platinum:/export/share";
    fsType = "nfs";
    neededForBoot = true;
  };
}
