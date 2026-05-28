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

  networking.firewall.enable = true;
}
