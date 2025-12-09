# cwwk monster NAS + Jonsbo N2, as a NAS.
{
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/rootfs";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

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
