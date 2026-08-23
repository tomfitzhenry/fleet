# Checks the health of btrfs filesystems, and emails a report when there are
# problems. Scrubs run via services.btrfs.autoScrub, and the check warns when
# the last scrub is older than 45 days.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.btrfs-health;
  pkg = pkgs.callPackage ../../pkgs/btrfs-health/package.nix { };
  # btrfs filesystems declared in NixOS config that should be mounted; a
  # noauto filesystem is intentionally unmounted.
  declaredBtrfs = lib.filterAttrs (
    _: fs: fs.fsType == "btrfs" && !(fs.noauto or false)
  ) config.fileSystems;
in
{
  options = {
    tomf.btrfs-health = {
      enable = lib.mkEnableOption "btrfs health checks";
      mailer = lib.mkOption {
        type = lib.types.path;
        default = "/run/wrappers/bin/sendmail";
        description = "Sendmail-compatible binary used to send problem reports.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.tomf.mail-relay.enable;
        message = "tomf.btrfs-health requires tomf.mail-relay to deliver the report; enable tomf.mail-relay or disable tomf.btrfs-health";
      }
    ];

    systemd.services.btrfs-health = {
      description = "Check btrfs filesystem health";
      serviceConfig = {
        Type = "oneshot";
        # A wedged btrfs ioctl should not hang the service forever.
        TimeoutStartSec = "10min";
        # A list ExecStart would render as several commands, so build one line.
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkg)
            "--mailer"
            (lib.escapeShellArg (toString cfg.mailer))
          ]
          ++ map lib.escapeShellArg (lib.attrNames declaredBtrfs)
        );
      };
    };

    systemd.timers.btrfs-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
