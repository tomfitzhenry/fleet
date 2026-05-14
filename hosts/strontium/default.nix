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

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
  services.knot = {
    enable = true;
    settings = {
      server = {
        listen = "::";
      };
      template = [
        {
          id = "member_template";
          acl = "local";
        }
      ];
      zone = [
        # A catalog zone. This allows the creation/deletion of zones via DNS UPDATE.
        # https://www.knot-dns.cz/docs/latest/html/configuration.html#catalog-zones
        {
          domain = "catz.";
          catalog-role = "interpret";
          catalog-template = "member_template";
          acl = "local";
        }
      ];
      remote = [
        {
          # https://ns-global.zone
          id = "ns-global";
          address = [
            "2607:7c80:54:6::53"
          ];
        }
        {
          # https://puck.nether.net/dns/
          id = "puck";
          address = [
            "2001:418:3f4::5"
          ];
        }
      ];
      acl = [
        {
          # Allow localhost to AXFR/transfer.
          # TODO: Add auth.
          id = "local";
          address = [ "::1" ];
          action = [
            "transfer"
            "update"
          ];
        }
        {
          # Allow ns-global to AXFR.
          id = "ns-global";
          address = [
            # https://ns-global.zone/signup/
            "2607:7c80:54:6::53"
          ];
          action = "transfer";
        }
        {
          # Allow puck.nether.net to AXFR.
          id = "puck";
          address = [
            # https://puck.nether.net/dns/static/faq.html
            "2602:fe55:5::5"
          ];
          action = "transfer";
        }
      ];
    };
  };
}
