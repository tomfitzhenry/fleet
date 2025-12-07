# A Pine64 RockPro64, acting as a NAS.
{
  pkgs,
  ...
}:
{
  imports = [
    ./nas.nix
  ];

  nixpkgs.system = "aarch64-linux";
  system.stateVersion = "25.05";

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
    luks = {
      devices = {
        share1 = {
          device = "/dev/sda3";
          tryEmptyPassphrase = true;
        };
        share2 = {
          device = "/dev/sdb3";
          tryEmptyPassphrase = true;
        };
      };
    };
  };

  boot.loader.systemd-boot.enable = true;

  tomf = {
    rootfs = {
      device = "/dev/disk/by-uuid/e73dba77-6da5-4ebf-b755-113ec19cbaa2";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      # Expose SSH to LAN.
      openFirewall = true;
    };
  };

  # Prevent frequent disk writes, to prevent HDDs spinning up.
  fileSystems."/var/log".fsType = "tmpfs";
  boot.tmp.useTmpfs = true;

  fileSystems."/srv/share" = {
    device = "/dev/mapper/share1";
  };

  systemd.services.hd-idle = {
    description = "External HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle";
      Restart = "always";
    };
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      frontend = true;
      mqtt.server = "mqtt://aluminium:1883";
      permit_join = true;
      serial.port = "/dev/ttyACM0";
    };
  };
}
