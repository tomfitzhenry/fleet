# Roughtime bootstraps the clock. The server list is authenticated by the
# pinned keys in servers.json, so its plaintext DNS lookup need not be trusted.
{ config, lib, pkgs, ... }:
let
  roughenough = pkgs.callPackage ../../pkgs/roughenough.nix { };

  resolvConf = pkgs.writeText "roughtime-resolv.conf" ''
    nameserver 9.9.9.9
    nameserver 2620:fe::fe
  '';
in
{
  options.tomf.roughtime.enable = lib.mkEnableOption "Roughtime clock bootstrap";

  config = lib.mkIf config.tomf.roughtime.enable {
    systemd.services.roughtime-sync = {
      description = "Bootstrap the clock with Roughtime";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = [ "network.target" ];
      before = [ "time-sync.target" ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        AmbientCapabilities = [ "CAP_SYS_TIME" ];
        CapabilityBoundingSet = [ "CAP_SYS_TIME" ];
        ExecStart = "${roughenough}/bin/roughenough_client -l ${./servers.json} -s -t 5 -P both -u 3 -r 2";
        BindReadOnlyPaths = [ "${resolvConf}:/etc/resolv.conf" ];
        # nsncd would otherwise resolve via the host, not this unit's resolv.conf.
        InaccessiblePaths = [ "/run/nscd/socket" ];
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStartSec = 90;
      };
    };
  };
}
