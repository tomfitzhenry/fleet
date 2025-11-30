# redbox is a PC Engines APU1 acting as a router.
{ config, ... }:
{
  nixpkgs.system = "x86_64-linux";
  system.stateVersion = "25.05";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.grub.extraConfig = "
    serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
    terminal_input serial
    terminal_output serial
  ";

  tomf = {
    rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-root";
      subvolume = "/root";
    };
    sshd = {
      enable = true;
      # Avoid exposing SSH to WAN.
      # Open it to LAN below.
      openFirewall = false;
    };
  };

  fileSystems."/nix" = {
    device = config.tomf.rootfs.device;
    fsType = "btrfs";
    options = [ "subvol=/nix" ];
    neededForBoot = true;
  };

  networking.firewall = {
    enable = true;
    # Avoid exposing services to WAN.
    interfaces.lan = {
      allowedTCPPorts = [
        22 # ssh
        53 # dns
      ];
      allowedUDPPorts = [
        53 # dns
      ];
    };
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "lan" ];
    externalInterface = "enp1s0";
  };

  networking.useDHCP = false;

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv4.conf.default.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  # Don't block on lack of connectivity.
  systemd.network.wait-online.enable = false;

  systemd.network = {
    enable = true;
    netdevs = {
      "lan" = {
        netdevConfig = {
          "Name" = "lan";
          "Kind" = "bridge";
        };
      };
    };
    networks = {
      "lan" = {
        name = "lan";
        address = [
          "172.17.1.1/24"
          "2404:bf40:81c1::1/64"
        ];
        bridgeConfig = {
          # Support Virtual Ethernet Port Aggregator (VEPA), per https://virt.kernelnewbies.org/MacVTap
          HairPin = true;
        };
      };
      "enp1s0" = {
        name = "enp1s0";
        address = [
	  "123.243.70.34/30"
          "2405:800:2:43::2/126"
        ];
        gateway = [
	  "123.243.70.33"
          "2405:800:2:43::1"
        ];
      };
      "enp2s0" = {
        name = "enp2s0";
        bridge = [ "lan" ];
      };
      "enp3s0" = {
        name = "enp3s0";
        bridge = [ "lan" ];
      };
    };
  };

  services.kea = {
    dhcp4 = {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = [
            "lan"
          ];
        };
        lease-database = {
          name = "/var/lib/kea/dhcp4.leases";
          persist = true;
          type = "memfile";
        };
        subnet4 = [
          {
            id = 1;
            interface = "lan";
            subnet = "172.17.1.0/24";
            pools = [
              {
                pool = "172.17.1.150 - 172.17.1.250";
              }
            ];
            valid-lifetime = 60 * 60 * 23;
            calculate-tee-times = true;
            option-data = [
              {
                name = "routers";
                data = "172.17.1.1";
              }
              {
                name = "domain-name-servers";
                data = "172.17.1.1";
              }
              {
                name = "tcode";
                data = "Australia/Sydney";
              }
            ];
            reservations = [
              {
                # PS4.
                hw-address = "78:c8:81:a9:55:e8";
                ip-address = "172.17.1.160";
              }
            ];
          }
        ];
      };
    };
  };

  services.corerad = {
    enable = true;
    settings = {
      interfaces = [
        {
          name = "lan";
          advertise = true;
          prefix = [ { prefix = "::/64"; } ];
          rdnss = [ { } ];
          route = [ { } ];
          verbose = true;
        }
      ];
    };
  };

  # Avoid port binding conflicts on port 53.
  services.resolved.enable = false;

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [
          "lan"

          # Act as local stub resolver, since we disabled resolved, so that unbound could listen on all IPs.
          "lo"
        ];
        access-control = [
          "0.0.0.0/0 allow"
          "::0/0 allow"
        ];
        log-servfail = true;
        prefetch = true;
        prefer-ip6 = true;
        local-zone = [
	  # Keep consoles off this network.
          ''"nintendo.com." refuse''
          ''"playstation.com." refuse''
          ''"xbox.com." refuse''
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            # https://quad9.net/
            "2620:fe::10#dns10.quad9.net"
            "2620:fe::fe:10#dns10.quad9.net"
            "9.9.9.10#dns10.quad9.net"
            "149.112.112.10#dns10.quad9.net"
          ];
          forward-tls-upstream = true;
        }
      ];
    };
  };
}
