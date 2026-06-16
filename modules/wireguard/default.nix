# A module providing a wireguard mesh.
#
# To add a new host:
#   * `(cd /etc/wireguard && umask 077 && wg genkey > wgFleet.key && wg pubkey < wgFleet.key)`
#   * Add entry below.
{ config, lib, ... }:
let
  cfg = config.tomf.wireguard;
  fleetHosts = import ../../lib/hosts.nix;
  port = 51820;
  mkPeer = id: publicKey: {
    ip = "192.168.2.${toString id}";
    publicKey = publicKey;
    relayPort = port + id;
    # Non-reachable peers should send keepalives so they become reachable.
    keepAlive = true;
  };
  mkReachablePeer =
    id: endpoint: publicKey:
    (mkPeer id publicKey) // { endpoint = endpoint; };
  # Use IPs to avoid bootstrap issues if/when DNS is broken.
  hosts = {
    oxygen = mkPeer 1 "KaNVCe+3pvRPFG/DznQDktplLMmP/7s5Vw5l6xjcpDs=";
    aluminium =
      mkReachablePeer 2 "[${fleetHosts.aluminium.ipv6}]"
        "Gfe6lYdGn+CDBokXOe1gVOysyZQJ8LwJrrViuR8vGyc=";
    platinum =
      mkReachablePeer 3 "[${fleetHosts.platinum.ipv6}]"
        "x7/D2CNMhUQnJZvUqOSfjj/8ZoYgd8mphgLAR0ZA9kA=";

    oxygen-nfs = mkPeer 4 "6Ay+BfxUNp2BAJgIjcpKhpQmm4xYTu5qHy031/YPYFU=";
    aluminium-nfs = mkPeer 5 "uKDhQedHX0ungfzCSSSGp9brbf2halh4fcdIRZS2f1s=";

    redbox =
      mkReachablePeer 6 "[${fleetHosts.redbox.ipv6}]"
        "SxFYSxgRscHQzdigsELNMyIzl7DMhTzpsv8aMJWkCzY=";
    strontium =
      mkReachablePeer 7 "[${fleetHosts.strontium.ipv6}]"
        "N7UcZ0F4AKvadlZ+PbHabhUaQ4d28FFtUd9BT73YpHs=";
  };
in
{
  options = {
    tomf.wireguard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ port ];
    networking.hosts = lib.attrsets.mapAttrs' (k: v: lib.nameValuePair v.ip [ k ]) hosts;

    networking.wireguard = {
      interfaces.wgFleet = {
        ips = [ (hosts."${config.networking.hostName}".ip + "/32") ];
        privateKeyFile = "/etc/wireguard/wgFleet.key";
        listenPort = port;
        mtu = 1280;
        peers = lib.attrsets.mapAttrsToList (_: v: {
          publicKey = v.publicKey;
          allowedIPs = [ "${v.ip}/32" ];
          endpoint = lib.mkIf (v ? endpoint) "${v.endpoint}:${toString port}";
          persistentKeepalive = lib.mkIf hosts."${config.networking.hostName}".keepAlive 300;
        }) hosts;
      };
    };
  };
}
