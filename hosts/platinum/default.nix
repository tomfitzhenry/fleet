# cwwk monster NAS + Jonsbo N2, as a NAS.
{
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

  tomf = {
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

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

  systemd.services.hd-idle = {
    description = "External HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle";
      Restart = "always";
    };
  };
}
