{ lib, microvm, ... }:
let
  fleetHosts = import ../../lib/hosts.nix;

  vms = [
    "dev"
    "feed"
    "git"
    "runner"
  ];

  mkTap = name: {
    "vm-${name}" = {
      matchConfig.Name = "vm-${name}";
      address = [ "fe80::1/128" ];
      routes = [
        { Destination = "${fleetHosts.${name}.ipv6}/128"; }
      ];
      networkConfig = {
        IPv6Forwarding = true;
        IPv6AcceptRA = false;
      };
    };
  };

  mkVm = name: {
    extraModules = [
      ../../modules/common
      ../../modules/microvm-guest
      ../../modules/sshd
    ];
    config = import ../../hosts/${name};
  };
in
{
  imports = [ microvm.nixosModules.host ];

  microvm = {
    host.enable = true;
    vms = lib.genAttrs vms mkVm;
  };

  # Routed TAP interfaces for VMs. Policy routing ensures VM traffic
  # traverses the LAN firewall rather than going directly to LAN
  # clients over L2.
  systemd.network.networks = {
    "40-wired" = {
      routes = [
        {
          Destination = "::/0";
          Gateway = "_ipv6ra";
          Table = 100;
        }
      ];
      routingPolicyRules = [
        {
          From = fleetHosts.aluminium.vmSubnet;
          Table = 100;
          Priority = 100;
        }
      ];
    };
  }
  // lib.mergeAttrsList (map mkTap vms);
}
