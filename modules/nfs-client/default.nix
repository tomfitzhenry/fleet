{
  config,
  lib,
  pkgs,
  ...
}:
let
  fleetHosts = import ../../lib/hosts.nix;
  cfg = config.tomf.nfs-client;
in
{
  options.tomf.nfs-client = {
    enable = lib.mkEnableOption "Isolated NFS mounts over WireGuard in a dedicated network namespace";
    wireguard = {
      ips = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = [ "10.0.0.2/32" ];
        description = "IP addresses for the wgNfs interface.";
      };
    };

    mounts = lib.mkOption {
      description = "List of NFS mounts to bind to the WireGuard namespace.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            what = lib.mkOption {
              type = lib.types.str;
              example = "/remote/path";
              description = "The remote NFS share path.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {

    boot.supportedFilesystems = [ "nfs" ];

    systemd.services.netns-nfs = {
      description = "Network namespace 'nfs' for isolated mounts";
      wantedBy = [ "network.target" ];
      # Keep the namespace stable across nixos-rebuild switch so that containers
      # bind-mounting the NFS share keep a stable reference to its superblock.
      # An explicit `systemctl stop netns-nfs` still tears it down via ExecStop.
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip netns add nfs";
        ExecStop = "${pkgs.iproute2}/bin/ip netns delete nfs";
      };
    };

    networking.wireguard.interfaces.wgNfs = {
      ips = cfg.wireguard.ips;
      privateKeyFile = "/etc/wireguard/wgNfs.key";
      peers = [
        {
          publicKey = "x7/D2CNMhUQnJZvUqOSfjj/8ZoYgd8mphgLAR0ZA9kA=";
          endpoint = "${fleetHosts.platinum.ipv6}:51820";
          allowedIPs = [ "192.168.2.3/32" ];
        }
      ];
      interfaceNamespace = "nfs";
    };

    # Inject dependencies to ensure the netns exists before WireGuard starts
    systemd.services."wireguard-wgNfs" = {
      requires = [ "netns-nfs.service" ];
      after = [ "netns-nfs.service" ];
    };

    systemd.mounts = lib.mapAttrsToList (mountPoint: mountCfg: {
      enable = true;
      where = mountPoint;
      what = "platinum:${mountCfg.what}";
      type = "nfs";
      options = "soft";

      mountConfig = {
        NetworkNamespacePath = "/var/run/netns/nfs";
        # We must disable, since it is otherwise enabled when NetworkNamespacePath is set.
        PrivateMounts = false;
      };

      unitConfig = {
        Requires = [ "wireguard-wgNfs.target" ];
        After = [ "wireguard-wgNfs.target" ];
        # Stop this mount when netns-nfs restarts (it deletes the namespace
        # the mount's NFS socket lives in); the automount re-fires on access.
        BindsTo = [ "netns-nfs.service" ];
      };
    }) cfg.mounts;

    systemd.automounts = lib.mapAttrsToList (mountPoint: mountCfg: {
      enable = true;
      where = mountPoint;
      wantedBy = [ "multi-user.target" ];
    }) cfg.mounts;

  };
}
