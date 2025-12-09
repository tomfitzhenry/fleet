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
