# redbox is a PC Engines APU1 acting as a router.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  snid = pkgs.callPackage ../../pkgs/snid { };
  httpsBackends = [
    "2404:bf40:81c1:0:e654:e8ff:fe7d:6173"
    "2404:bf40:81c1:0:aab8:e0ff:fe06:ae27"
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
    extraForwardRules = lib.concatMapStrings (
      host: "ip6 daddr ${host} tcp dport 443 counter accept\n"
    ) httpsBackends;
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
          # Don't advertise this router as a default IPv6 gateway — ISP's IPv6 is broken.
          # Setting default_lifetime to 0 clears the Router Lifetime field in RAs,
          # so clients won't use this router as a default route.
          # Clients will still get LAN IPv6 addresses via the prefix below.
          default_lifetime = "0s";
          prefix = [ { prefix = "::/64"; } ];
          rdnss = [ { } ];
          # Don't advertise a default IPv6 route — ISP's IPv6 is broken.
          # Clients will still get LAN IPv6 addresses via the prefix above.
          #
          # Advertise a route for the snid NAT46 prefix so that LAN backends can
          # reply to connections proxied by snid — their reply packets are destined
          # to 64:ff9b:1::<client-ipv4> and need a path back through the router.
          route = [ { prefix = "64:ff9b:1::/96"; } ];
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

  systemd.services.snid = {
    description = "SNI-based TLS proxy";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = pkgs.lib.concatStringsSep " " (
        [
          "${snid}/bin/snid"
          "-listen tcp:0.0.0.0:443"
          "-mode nat46"
          "-nat46-prefix 64:ff9b:1::"
        ]
        ++ map (host: "-backend-cidr ${host}/128") httpsBackends
      );
      Restart = "on-failure";
      DynamicUser = true;
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
      in
      {
        assertion =
          networkOnlineReverseDependencies == [
            "kea-dhcp4-server"
          ];
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
