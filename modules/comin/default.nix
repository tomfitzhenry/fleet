# A module that manages comin.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.tomf.comin;
in
{
  options = {
    tomf.comin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: Remove if/when comin supports gittuf.
    systemd.timers."fleet-repo-poller" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:0/10:00";
        Persistent = true;
      };
    };

    systemd.services."fleet-repo-poller" = {
      script = ''
        	  set -eu
              if [ ! -d repo ]; then
                  git clone https://codeberg.org/tomf/fleet repo
              fi

              cd repo
              git pull
              git fetch origin refs/gittuf/*:refs/gittuf/*

              gittuf verify-ref master

              cd ..
              rm -rf repo-staging
              cp -r repo repo-staging
              mkdir -p repo-live
              ${pkgs.util-linux}/bin/exch repo-staging repo-live
        	'';
      path = [
        pkgs.git
        pkgs.gittuf
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "/var/lib/fleet-repo-poller";
        StateDirectory = "fleet-repo-poller";
      };
    };

    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = "/var/lib/fleet-repo-poller/repo-live";
          branches.main.name = "master";
          poller.period = 60 * 5; # 5 mins
        }
      ];
    };

  };
}
