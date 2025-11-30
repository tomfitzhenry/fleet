{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  time.timeZone = "Australia/Sydney";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  # Yubikey PIV.
  services.pcscd.enable = true;

  # Yubikey OATH.
  services.udev.packages = [ pkgs.yubikey-personalization ];

  fileSystems."/" =
    { device = "/dev/mapper/enc";
      fsType = "btrfs";
    };

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/b210a23c-b423-466d-afd1-c383a1b37a64";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" ];

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [
    firefox
  ];
}
