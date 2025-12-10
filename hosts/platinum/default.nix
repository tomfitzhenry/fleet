# cwwk monster NAS + Jonsbo N2, as a NAS.
{
  pkgs,
  ...
}:
{
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
    "intel_idle.max_cstate=4"
  ];

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
}
