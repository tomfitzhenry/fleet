# redbox is a PC Engines APU1 acting as a router.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  snid = pkgs.callPackage ../../pkgs/snid/package.nix { };
  fleetHosts = import ../../lib/hosts.nix;
  httpsBackends = [
    fleetHosts.aluminium.ipv6
    fleetHosts.platinum.ipv6
  ];
  wireguardBackends = [
    fleetHosts.aluminium.ipv6
    fleetHosts.platinum.ipv6
  ];
in
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
    podman.enable = true;
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
    wireguard.enable = true;
  };

  fileSystems."/nix" = {
    device = config.tomf.rootfs.device;
    fsType = "btrfs";
    options = [ "subvol=/nix" ];
    neededForBoot = true;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      443 # https
    ];
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

    filterForward = true;
    extraForwardRules = lib.concatLines (
      [ "ip6 daddr ${fleetHosts.aluminium.vmSubnet} counter accept" ]
      ++ map (host: "ip6 daddr ${host} tcp dport 443 counter accept") httpsBackends
      ++ map (host: "ip6 daddr ${host} udp dport 51820 counter accept") wireguardBackends
    );
  };

  # Allow non-privileged Podman containers to listen on 443/tcp.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

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
        ];
        bridgeConfig = {
          # Support Virtual Ethernet Port Aggregator (VEPA), per https://virt.kernelnewbies.org/MacVTap
          HairPin = true;
        };
        networkConfig = {
          DHCPPrefixDelegation = true;
        };
        dhcpPrefixDelegationConfig = {
          UplinkInterface = "enp1s0";
          SubnetId = 1;
          # corerad handles router advertisements for the LAN.
          Announce = false;
        };
        routes = [
          {
            # Route VM subnet to aluminium.
            Destination = fleetHosts.aluminium.vmSubnet;
            Gateway = fleetHosts.aluminium.ipv6;
          }
        ];
      };
      "enp1s0" = {
        name = "enp1s0";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
        dhcpV4Config = {
          UseDNS = false;
          UseNTP = false;
        };
        dhcpV6Config = {
          UseDNS = false;
          UseNTP = false;
          PrefixDelegationHint = "::/48";
          # Solicit a prefix regardless of the RA's M/O flags.
          WithoutRA = "solicit";
        };
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

          # Kea by default does not exit on startup if it fails to bind a socket.
          # This can happen if Kea starts before the 'lan' interface is created.
          # So let's add retries, and exit if the interface fails to bind.
          # https://gitlab.isc.org/isc-projects/kea/-/issues/2776
          service-sockets-max-retries = 5;
          service-sockets-require-all = true;
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

  networking.localCommands = ''
    # Per https://github.com/AGWA/snid?tab=readme-ov-file#-nat46-prefix-ipv6address-mandatory
    ip -6 route add local 64:ff9b:1::/96 dev lo
  '';

  system.services.snid = {
    imports = [ snid.services.default ];
    snid = {
      listen = [ "tcp:0.0.0.0:443" ];
      mode = "nat46";
      nat46Prefix = "64:ff9b:1::";
      backendCidrs = map (host: "${host}/128") httpsBackends;
    };
  };

  assertions = [
    (
      let
        networkOnlineReverseDependencies = lib.attrNames (
          lib.filterAttrs (
            name: service: lib.elem "network-online.target" service.after
          ) config.systemd.services
        );
        allowlist = [
          "kea-dhcp4-server"
          # wireguard depends on network-online.target (I guess for DNS resolution?).
          # This would make wireguard unavailable if DNS was down.
          # To mitigate this, our wireguard module relies on IPs directly.
          "wireguard-"
        ];
        allTargetsValid = lib.all (
          target: lib.any (prefix: lib.hasPrefix prefix target) allowlist
        ) networkOnlineReverseDependencies;
      in
      {
        assertion = allTargetsValid;
        message = ''
          The following services depend on 'network-online.target'. 
          To maintain a robust/self-healing router, remove these dependencies and 
          configure the services to retry on failure instead.

          Violating services: ${lib.concatStringsSep ", " networkOnlineReverseDependencies}
        '';
      }
    )
  ];
}
