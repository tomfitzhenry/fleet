# A module for managing tlshd.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.tomf.tlshd;
  iniFormat = pkgs.formats.ini { };
  configFile = iniFormat.generate "tlshd.conf" cfg.settings;
in
{
  options = {
    tomf.tlshd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ktls-utils;
        description = "The ktls-utils package providing tlshd.";
      };
      settings = lib.mkOption {
        type = iniFormat.type;
        default = { };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tls" ];

    systemd.services.tlshd = {
      description = "TLS Handshake Daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/tlshd --stderr --config ${configFile}";
        Restart = "on-failure";
        StateDirectory = "tlshd";

        # The privileges that the daemon needs.
        User = "root";
        Group = "root";
        PrivateUsers = false;
        PrivateNetwork = false;
        RestrictAddressFamilies = [ "AF_NETLINK" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];

        # Restrict other privileges.
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
