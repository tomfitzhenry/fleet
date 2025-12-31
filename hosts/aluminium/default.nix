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
    podman.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

  users.users.podman.extraGroups = [
    "render" # hw acceleration
  ];

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
  };
}
