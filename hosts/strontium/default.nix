# An IPv6-only VM from iFog
# https://v6only.ch/
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.system = "x86_64-linux";
  networking.hostName = "strontium";
  system.stateVersion = "25.04";

  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
    "earlyprintk=ttyS0,115200"
    "consoleblank=0"
  ];

  boot.loader.grub = {
    device = "/dev/sda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/disk/by-uuid/212006ad-c976-4a1e-ac3b-a7f83ea52de7";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks = {
      ens18 = {
        matchConfig = {
          Name = "ens18";
        };
        networkConfig = {
          Address = [
            "2a0c:9a40:2510:1001::10eb/64"
          ];
          Gateway = "2a0c:9a40:2510:1001::1";
          DNS = [
            "2606:4700:4700::1111"
          ];
        };
      };
    };
  };

  # This machine is IPv6-only, so let's provide connectivity via a public NAT64 gateway.
  services.clatd = {
    enable = true;
    # https://nat64.xyz/
    # https://level66.services/services/nat64/
    settings.plat-prefix = "2001:67c:2960:6464::/96";
  };
}
