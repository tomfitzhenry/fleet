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
    # Serial
    "console=ttyS2,1500000n8"

    # Console on HDMI
    "console=tty0"
  ];

  boot.initrd = {
    kernelModules = [
      # Serial console
      "8250_dw"

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
