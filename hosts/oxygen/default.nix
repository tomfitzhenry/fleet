{ pkgs, ... }:
let
  fleetHosts = import ../../lib/hosts.nix;
in
{
  nixpkgs.hostPlatform = "x86_64-linux";
  time.timeZone = "Australia/Sydney";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/b210a23c-b423-466d-afd1-c383a1b37a64";

  tomf = {
    nfs-client = {
      enable = true;
      wireguard.ips = [ "192.168.2.4/32" ];
      mounts = {
        "/mnt/share" = {
          what = "/export/share";
        };
        "/mnt/tom" = {
          what = "/export/tom";
        };
      };
    };
    otel-collector.enable = true;
    rootfs = {
      device = "/dev/mapper/enc";
      subvolume = "/";
    };
    remote-builders.enable = true;
    sshd.enable = false;
    wireguard.enable = true;
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

  users.users.tom.extraGroups = [
    "dialout" # for picocom
  ];
  nix.gc.automatic = false; # for dev
}
