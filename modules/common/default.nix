{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.grub.configurationLimit = 15;

  hardware.firmware = [
    pkgs.linux-firmware
  ];

  nix.gc.automatic = lib.mkDefault true;

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  services.tailscale.enable = true;

  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://codeberg.org/tomf/fleet";
        branches.main.name = "master";
        poller.period = 60 * 5; # 5 mins
      }
    ];
  };
}
