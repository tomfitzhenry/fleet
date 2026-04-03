{ ... }:
{
  name = "redbox";

  nodes = {
    upstream =
      { pkgs, lib, ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.useNetworkd = true;
        networking.useDHCP = false;
        # Disable test framework's static IP assignment
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        networking.interfaces.eth1.ipv6.addresses = lib.mkForce [ ];

        # Configure eth1 with upstream IP
        systemd.network.enable = true;
        systemd.network.networks."10-eth1" = {
          matchConfig.Name = "eth1";
          address = [
            "123.243.70.33/30"
            "2405:800:2:43::1/126"
          ];
          routes = [
            {
              Destination = "2404:bf40:81c1::/64";
              Gateway = "2405:800:2:43::2";
            }
          ];
        };
      };

    redbox =
      { pkgs, lib, ... }:
      {
        virtualisation.vlans = [
          1
          2
        ];
        imports = [
          ./default.nix
          ../../modules/common
          ../../modules/podman
          ../../modules/rootfs
          ../../modules/sshd
        ];

        tomf.rootfs.enable = false;

        # Override hardware/boot configurations that break in VM
        boot.loader.grub.enable = lib.mkForce false;

        # Override network names for VM
        systemd.network.networks."enp1s0".name = lib.mkForce "eth1";
        systemd.network.networks."enp2s0".name = lib.mkForce "eth2";
        systemd.network.networks."enp3s0".enable = lib.mkForce false;
        networking.nat.externalInterface = lib.mkForce "eth1";

        # Disable test framework's static IP assignment
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        networking.interfaces.eth1.ipv6.addresses = lib.mkForce [ ];
        networking.interfaces.eth2.ipv4.addresses = lib.mkForce [ ];
        networking.interfaces.eth2.ipv6.addresses = lib.mkForce [ ];
      };

    client =
      { pkgs, lib, ... }:
      {
        virtualisation.vlans = [ 2 ];
        networking.useDHCP = false;
        networking.useNetworkd = true;
        systemd.network.enable = true;
        systemd.network.networks."10-eth1" = {
          matchConfig.Name = "eth1";
          networkConfig.DHCP = "yes";
          networkConfig.IPv6AcceptRA = "yes";
        };
        # Disable test framework's static IP assignment
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        networking.interfaces.eth1.ipv6.addresses = lib.mkForce [ ];
      };
  };

  testScript = ''
    start_all()

    upstream.wait_for_unit("systemd-networkd.service")
    redbox.wait_for_unit("systemd-networkd.service")
    redbox.wait_for_unit("kea-dhcp4-server.service")
    redbox.wait_for_unit("corerad.service")

    client.wait_for_unit("systemd-networkd.service")

    # Wait for client to get IPv6 SLAAC address
    client.wait_until_succeeds("ip -6 addr show dev eth1 | grep '2404:bf40:81c1:'")

    # Client pings upstream IPv6
    client.succeed("ping -c 3 2405:800:2:43::1 -I eth1")
  '';
}
