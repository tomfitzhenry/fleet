# cwwk monster NAS + Jonsbo N2, as a NAS.
{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./nas.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  hardware.cpu.intel.updateMicrocode = true;

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/rootfs";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

  boot.kernelPatches = [
    {
      name = "enable-usb-dbgcap";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        USB_XHCI_DBGCAP = yes;
      };
    }
  ];

  boot.kernelParams = [
    # The machine hangs shortly after getting to getty, and this goes away if we limit the max Intel C-state.
    # Intel C6 seems stable with 4800MHz DDR5.
    # Intel C8 seems stable with 3200MHz DDR5 (i.e. underclocked).
    #
    # For a NAS, I prefer more power saving than faster RAM, so let's go with Intel C8.
    #
    # On this board, the cstate -> Intel C mapping is:
    #   3 -> Intel C6
    #   4 -> Intel C8
    #   5 -> Intel C10
    #
    # Update: Instability returned after plugging in SATA drives. Bad PSU? Dropping max cstate to C6.
    "intel_idle.max_cstate=3"
  ];

  # Experiments in more power saving...
  specialisation = {
    pcie-sleep.configuration = {
      boot.kernelParams = [
        "nvme_core.default_ps_max_latency_us=5500"
        "i915.enable_guc=3"
      ];
    };
  };

  # Workaround OS hangs.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use out-of-tree driver until IT8613E is supported in mainline.
  boot.extraModulePackages = [ pkgs.linuxPackages_latest.it87 ];
  boot.kernelModules = [
    "drivetemp"
    # Fan driver for CWWK NAS motherboard.
    "it87"
  ];

  tomf = {
    podman.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    wireguard.enable = true;
  };

  # Allow non-privileged Podman containers to listen on 443/tcp.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  networking.firewall.allowedTCPPorts = [
    443 # https
  ];

  boot.initrd.luks.devices = {
    share1 = {
      device = "/dev/disk/by-uuid/1abdf7a3-7712-48f3-8f77-9067561fbb73";
      tryEmptyPassphrase = true;
    };
    share2 = {
      device = "/dev/disk/by-uuid/77e38ce5-3dd6-4b38-8e02-c074d009537f";
      tryEmptyPassphrase = true;
    };
    share3 = {
      device = "/dev/disk/by-uuid/13af40d6-7de7-44af-99d5-798e210b151d";
      tryEmptyPassphrase = true;
    };
    share4 = {
      device = "/dev/disk/by-uuid/a633ae97-cfa1-4343-8740-b450c95df8aa";
      tryEmptyPassphrase = true;
    };
  };

  fileSystems."/srv/share" = {
    device = "/dev/mapper/share1";
    fsType = "btrfs";
  };

  # "The user is supposed to run [scrub] manually or via a periodic system service. The recommended period is a month but it could be less."
  # https://btrfs.readthedocs.io/en/latest/Scrub.html
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      "/srv/share"
    ];
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

  systemd.services.fan2go =
    let
      cfg = (pkgs.formats.yaml { }).generate "fan2go.yaml" {
        dbPath = "/var/lib/fan2go/fan2go.db";
        fans = [
          {
            id = "hdd-fan";
            hwmon = {
              platform = "it8613-isa-0a20";
              # SYSFAN, plugged into HDD back plate.
              rpmChannel = 3;
            };
            neverStop = true;
            curve = "hottest-hdd-curve";
            minPwm = 80;
            maxPwm = 255;
          }
        ];
        sensors = [
          {
            id = "hdd1";
            hwmon = {
              platform = "drivetemp-scsi-1-0";
              index = 1;
            };
          }
          {
            id = "hdd2";
            hwmon = {
              platform = "drivetemp-scsi-2-0";
              index = 1;
            };
          }
          {
            id = "hdd3";
            hwmon = {
              platform = "drivetemp-scsi-3-0";
              index = 1;
            };
          }
          {
            id = "hdd4";
            hwmon = {
              platform = "drivetemp-scsi-4-0";
              index = 1;
            };
          }
        ];
        curves = [
          {
            id = "hdd1-c";
            linear = {
              sensor = "hdd1";
              min = 35;
              max = 50;
            };
          }
          {
            id = "hdd2-c";
            linear = {
              sensor = "hdd2";
              min = 35;
              max = 50;
            };
          }
          {
            id = "hdd3-c";
            linear = {
              sensor = "hdd3";
              min = 35;
              max = 50;
            };
          }
          {
            id = "hdd4-c";
            linear = {
              sensor = "hdd4";
              min = 35;
              max = 50;
            };
          }
          {
            id = "hottest-hdd-curve";
            function = {
              type = "maximum";
              curves = [
                "hdd1-c"
                "hdd2-c"
                "hdd3-c"
                "hdd4-c"
              ];
            };
          }
        ];
      };
    in
    {
      description = "Fan controller";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.fan2go}/bin/fan2go --config ${cfg}";
        StateDirectory = "fan2go";
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
