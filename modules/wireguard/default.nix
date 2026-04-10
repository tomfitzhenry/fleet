# A module providing a wireguard mesh.
{ config, lib, ... }:
let
  cfg = config.tomf.wireguard;
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
      mkReachablePeer 2 "2404:bf40:81c1:0:e654:e8ff:fe7d:6173"
        "KaNVCe+3pvRPFG/DznQDktplLMmP/7s5Vw5l6xjcpDs=";
    platinum =
      mkReachablePeer 3 "2404:bf40:81c1:0:aab8:e0ff:fe06:ae27"
        "x7/D2CNMhUQnJZvUqOSfjj/8ZoYgd8mphgLAR0ZA9kA=";
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

    networking.wireguard = {
      interfaces.wgFleet = {
        ips = [ (hosts."${config.networking.hostName}".ip + "/32") ];
        privateKeyFile = "/etc/wireguard/wgFleet.key";
        listenPort = port;
        mtu = 1420;
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
