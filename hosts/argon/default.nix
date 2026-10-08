# Oracle Cloud ARM VM.
{ config, ... }:
{
  nixpkgs.system = "aarch64-linux";
  system.stateVersion = "25.11";

  boot.initrd.availableKernelModules = [
    "nvme"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
  ];

  boot.loader.systemd-boot.enable = true;

  fileSystems."/nix" = {
    device = config.tomf.rootfs.device;
    fsType = "btrfs";
    options = [ "subvol=/nix" ];
    neededForBoot = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-root";
      subvolume = "/rootfs";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };
}
