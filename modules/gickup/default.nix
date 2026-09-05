# Mirrors every repository under codeberg.org/tomf to a local btrfs directory
# on the host, so a codeberg outage or account loss doesn't mean losing the
# repos. gickup refreshes bare mirrors in place each run, so a run is mostly
# fetches. The mirrors live on platinum's array (/srv/share/codeberg), which
# the host's btrbk 'share' snapshots version.
#
# The codeberg API token authenticates the run. It is not stored in this
# repository; install it by hand on the host before the first run:
#
#   install -d -m 0700 /etc/gickup
#   install -m 0400 <token-file> /etc/gickup/token
#
# Create the token at codeberg.org/settings/applications with the read:user and
# read:repository scopes. systemd's LoadCredential hands it to the service at
# /run/credentials/gickup.service/token, so a replacement token is picked up
# without a config change.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.gickup;
  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "gickup.yml" {
    source.gitea = [
      {
        url = "https://codeberg.org";
        user = "tomf";
        token_file = "/run/credentials/gickup.service/token";
      }
    ];
    destination.local = [
      {
        path = "/srv/share/codeberg";
        structured = true;
        bare = true;
        mirror = true;
      }
    ];
  };
  # gickup logs a run's failures at error level and exits non-zero, which is
  # what triggers the mail below.
  failureMail = pkgs.writeShellScript "gickup-failure-mail" ''
    {
      echo "Subject: gickup failed on ${config.networking.hostName}"
      echo
      journalctl -u gickup.service -n 50 --no-pager
    } | /run/wrappers/bin/sendmail -i -t
  '';
in
{
  options.tomf.gickup = {
    enable = lib.mkEnableOption "the gickup codeberg mirror";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.tomf.mail-relay.enable;
        message = "tomf.gickup requires tomf.mail-relay to deliver failure mail; enable tomf.mail-relay or disable tomf.gickup";
      }
    ];

    users.groups.gickup = { };
    users.users.gickup = {
      isSystemUser = true;
      group = "gickup";
    };

    systemd.services.gickup = {
      description = "Mirror codeberg.org/tomf with gickup";
      wantedBy = [ ];
      wants = [ "network-online.target" ];
      # Don't run (and never create the destination on the root filesystem)
      # unless the array is mounted. /srv/share is an fstab mount, so the
      # fstab-generator provides this unit at boot.
      requires = [ "srv-share.mount" ];
      after = [
        "srv-share.mount"
        "network-online.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "gickup";
        Group = "gickup";
        # The destination is a plain subdirectory of the array's top-level
        # subvolume, and the array is root-owned, so create it as root (the
        # "+"). The ordering above guarantees the array is mounted by now.
        ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o gickup -g gickup -m 0750 /srv/share/codeberg";
        ExecStart = "${pkgs.gickup}/bin/gickup ${configFile}";
        LoadCredential = "token:/etc/gickup/token";
        # Cloning the largest forks (e.g. linux) can take a while.
        TimeoutStartSec = "6h";
      };
      onFailure = [ "gickup-failure-mail.service" ];
    };

    systemd.services.gickup-failure-mail = {
      description = "Mail that the gickup mirror failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = failureMail;
      };
    };

    systemd.timers.gickup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:00:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
