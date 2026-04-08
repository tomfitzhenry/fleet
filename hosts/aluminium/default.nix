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
    remote-builders.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    tlshd = {
      enable = true;
      settings = {
        "authenticate.client" = {
          "x509.certificate" = "/var/lib/tlshd/cert.pem";
          "x509.private_key" = "/var/lib/tlshd/key.pem";
          "x509.truststore" = "/var/lib/tlshd/truststore.pem";
        };
      };
    };
  };

  # Allow non-privileged Podman containers to listen on 443/tcp.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  networking.firewall.allowedTCPPorts = [
    443 # https
  ];

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
    options = [
      # Authenticate with mTLS.
      "xprtsec=mtls"
    ];
  };
}
