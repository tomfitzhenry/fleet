# An on-demand PKCS#11 proxy daemon for local systemd services.
#
# p11-hostd listens on a single Unix domain socket. Each connecting process is
# identified via SO_PEERCRED and mapped to its systemd unit; on first contact a
# P-256 key is provisioned for that unit and served over the p11-kit RPC
# protocol. The key bytes never leave the daemon: clients only receive
# signatures.
#
# A service opts in by pointing p11-kit at the daemon's socket:
#
#   systemd.services.grafana.serviceConfig.Environment =
#     [ "P11_KIT_SERVER_ADDRESS=unix:path=/run/p11-hostd.sock" ];
{
  config,
  lib,
  pkgs,
  p11-hostd,
  ...
}:
let
  cfg = config.tomf.p11-hostd;
in
{
  options.tomf.p11-hostd = {
    enable = lib.mkEnableOption "the p11-hostd on-demand PKCS#11 proxy daemon";

    package = lib.mkOption {
      type = lib.types.package;
      # p11-hostd is not packaged in nixpkgs, so default to the pinned flake's
      # package (built against its own nixpkgs-unstable).
      default = p11-hostd.packages.${pkgs.system}.default;
      description = "The p11-hostd package to run.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/p11-hostd";
      description = "Directory under which provisioned keys are stored.";
    };

    socket = lib.mkOption {
      type = lib.types.path;
      default = "/run/p11-hostd.sock";
      description = "Unix domain socket that clients connect to.";
    };

    socketMode = lib.mkOption {
      type = lib.types.str;
      default = "0666";
      description = "Permission bits for the socket file (octal).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.p11-hostd = {
      description = "p11-hostd on-demand PKCS#11 proxy daemon";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStart = lib.concatStringsSep " " [
          "${cfg.package}/bin/p11-hostd"
          "--state-dir=${cfg.stateDir}"
          "--socket=${cfg.socket}"
          "--socket-mode=${cfg.socketMode}"
        ];
        StateDirectory = lib.removePrefix "/var/lib/" cfg.stateDir;
        # The daemon reads SO_PEERCRED and /proc/<pid>/cgroup of every local
        # process and binds /run; it runs as root.
        DynamicUser = false;
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
