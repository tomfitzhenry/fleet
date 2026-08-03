# A Pine64 RockPro64.
{
  config,
  pkgs,
  ...
}:
{
  nixpkgs.system = "aarch64-linux";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  boot.kernelParams = [
    # Console on HDMI
    "console=ttyS0"
    "console=tty0"
  ];

  boot.blacklistedKernelModules = [
    # Spams klog.
    "bluetooth"
  ];

  boot.initrd = {
    kernelModules = [
      # HDMI
      "rockchipdrm"

      # PCIe/NVMe
      "pcie_rockchip_host"
      "phy_rockchip_pcie"
    ];
    luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-luks";
      tryEmptyPassphrase = true;
    };
  };

  fileSystems."/nix" = {
    device = config.tomf.rootfs.device;
    fsType = "btrfs";
    options = [ "subvol=/nix" ];
    neededForBoot = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/rootfs";
    };
    sshd = {
      enable = true;
      # Expose SSH to LAN.
      openFirewall = true;
    };
  };
}
