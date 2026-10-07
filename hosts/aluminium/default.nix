# Optiplex 7070 Micro, a development host.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./rockchip.nix
    ./sunxi.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-enc";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

  nix.gc.automatic = false; # for dev

  tomf = {
    nfs-client = {
      enable = true;
      wireguard.ips = [ "192.168.2.5/32" ];
      mounts = {
        "/mnt/share" = {
          what = "/export/share";
        };
      };
    };
    remote-builders.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    wireguard.enable = true;
  };

  services.udev.packages = [
    pkgs.probe-rs-tools
  ];
  users.groups.plugdev = { };
  users.users.dev = {
    uid = 1001;
    isNormalUser = true;
    extraGroups = [
      config.security.tpm2.tssGroup
      "dialout"
      "plugdev"
    ];
    linger = true;
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGUYYx2b7mHdXTxbnHh3euAUNyn+8aC2J2kOCUmp+JjbwipmjH3MbDjwjCvO7Z89wgVFmw0mL4y7EWucNaZqbKQ= tom@oxygen"
      # cros
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtJLuP7ptqokYFS1U9gskAg4u8wRpTb/jEfJlV7Whab"
    ];
  };

  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."40-wired" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
    };
    # Don't let networkd manage wireguard interfaces; they're managed by
    # the scripted networking wireguard module.
    networks."30-wireguard" = {
      matchConfig.Name = "wg*";
      linkConfig.Unmanaged = "yes";
    };
  };
}
