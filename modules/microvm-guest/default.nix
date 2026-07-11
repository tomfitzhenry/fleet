# Common configuration for microvm guests on aluminium.
{ config, ... }:
let
  fleetHosts = import ../../lib/hosts.nix;
  name = config.networking.hostName;
  host = fleetHosts.${name};
in
{
  microvm = {
    hypervisor = "qemu";
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ]
    ++
      map
        (dir: {
          tag = "persist-${dir}";
          source = "/mnt/btrfs/vm/${name}/${dir}";
          mountPoint = "/${dir}";
          proto = "virtiofs";
        })
        [
          "etc"
          "home"
          "var"
        ];
    interfaces = [
      {
        type = "tap";
        id = "vm-${name}";
        mac = host.mac;
      }
    ];
  };

  systemd.network = {
    enable = true;
    networks."20-eth" = {
      matchConfig.Type = "ether";
      address = [ "${host.ipv6}/128" ];
      routes = [
        {
          Destination = "::/0";
          Gateway = "fe80::1";
          GatewayOnLink = true;
        }
      ];
      networkConfig.IPv6AcceptRA = false;
    };
  };

  systemd.tmpfiles.rules = [
    "z /etc 0755 root root - -"
    "z /home 0755 root root - -"
    "z /var 0755 root root - -"
  ];

  networking.firewall.enable = true;
}
