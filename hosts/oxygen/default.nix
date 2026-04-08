{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  time.timeZone = "Australia/Sydney";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/b210a23c-b423-466d-afd1-c383a1b37a64";

  tomf = {
    rootfs = {
      device = "/dev/mapper/enc";
      subvolume = "/";
    };
    remote-builders.enable = true;
    sshd.enable = false;
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

  swapDevices = [
    {
      device = "/swapfile";
    }
  ];

  programs.sway.enable = true;
  programs.niri.enable = true;
  services.upower.enable = true;
  networking.networkmanager.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  hardware.bluetooth.enable = true;

  # Yubikey PIV.
  services.pcscd.enable = true;

  services.udev.packages = [
    # Yubikey OATH.
    pkgs.yubikey-personalization

    # nanoDLA.
    pkgs.libsigrok
  ];

  fileSystems = {
    "/mnt/share" = {
      device = "platinum:/export/share";
      fsType = "nfs";
      options = [
        "xprtsec=mtls"
      ];
    };
    "/mnt/tom" = {
      device = "platinum:/export/tom";
      fsType = "nfs";
      options = [
        "xprtsec=mtls"
      ];
    };
  };

  users.users.tom.extraGroups = [
    "dialout" # for picocom
  ];
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];
  nix.gc.automatic = false; # for dev
}
