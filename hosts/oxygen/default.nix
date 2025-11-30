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
    sshd.enable = false;
  };

  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.flatpak.enable = true;

  # Yubikey PIV.
  services.pcscd.enable = true;

  # Yubikey OATH.
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # GPG.
  programs.gnupg.agent.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
  ];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];
  nix.gc.automatic = false; # for dev
}
