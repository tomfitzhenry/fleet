# Optiplex 7070 Micro, a VM/container host.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./microvm-host.nix
    ../../modules/step-ca
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
    podman.enable = true;
    remote-builders.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    step-ca.enable = true;
    wireguard.enable = true;
  };

  boot.kernel.sysctl = {
    # Allow non-privileged Podman containers to listen on 443/tcp.
    "net.ipv4.ip_unprivileged_port_start" = 443;
    # Forward traffic to microVMs.
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.firewall.allowedTCPPorts = [
    443 # https
  ];

  networking.firewall.interfaces.wgFleet.allowedTCPPorts = [
    1883
  ];

  users.users.podman.extraGroups = [
    "render" # hw acceleration
  ];

  users.users.dev = {
    uid = 1001;
    isNormalUser = true;
    extraGroups = [
      config.security.tpm2.tssGroup
    ];
    linger = true;
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGUYYx2b7mHdXTxbnHh3euAUNyn+8aC2J2kOCUmp+JjbwipmjH3MbDjwjCvO7Z89wgVFmw0mL4y7EWucNaZqbKQ= tom@oxygen"
      # cros
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtJLuP7ptqokYFS1U9gskAg4u8wRpTb/jEfJlV7Whab"
    ];
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
