{ pkgs, ... }:
let
  fleetHosts = import ../../lib/hosts.nix;
in
{
  nixpkgs.hostPlatform = "x86_64-linux";
  time.timeZone = "Australia/Sydney";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  boot.kernelParams = [
    "nmi_watchdog=panic"
    "panic=30"
  ];
  boot.kernel.sysctl."kernel.sysrq" = "1";

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

  # Swapfile in its own subvolume, since btrfs refuses to snapshot a
  # subvolume with an active swapfile.
  #
  #   sudo btrfs filesystem mkswapfile --size 8G /mnt/btrfs/@swap/swapfile
  #
  fileSystems."/swap" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
    neededForBoot = true;
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];

  # The machine hangs under memory pressure. oomd is enabled by default, but no
  # slices are configured, so it does nothing. Cover the root slice and user
  # slices (Fedora's defaults) so runaway processes get killed.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  # Monthly btrfs scrub (set in modules/rootfs) catches up at boot via the
  # Persistent timer; throttle it so it's gentler on the disk while working.
  services.btrfs.autoScrub.limit = "100M";

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

  services.fwupd.enable = true;

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
