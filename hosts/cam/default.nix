# cam is a Pine64 PineCube IP camera.
{
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "armv7l-linux";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;

  boot.kernelPackages = pkgs.linuxPackagesFor (
    # Builds a small kernel that has most of what we need.
    pkgs.linux.override { defconfig = "sunxi_defconfig"; }
  );
  boot.kernelPatches = [
    {
      name = "pinecube-camera";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        VIDEO_OV5640 = module;
      };
    }
  ];

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "cma=32M"
  ];

  tomf = {
    # 128MB RAM is too little RAM.
    comin.enable = false;

    rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-root";
      subvolume = "/root";
    };

    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

  networking.useDHCP = true;
}
