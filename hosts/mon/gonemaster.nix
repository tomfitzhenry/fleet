{
  config,
  lib,
  pkgs,
  ...
}:
let
  gonemaster = pkgs.callPackage ../../pkgs/gonemaster/package.nix { };
  port = 9117;
  tag = "monitoring";
in
{
  systemd.services.gonemaster-server = {
    description = "Gonemaster DNS health server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe gonemaster}-server --listen 127.0.0.1:${toString port} --db-driver sqlite --db-dsn /var/lib/gonemaster/jobs.db";
      DynamicUser = true;
      StateDirectory = "gonemaster";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.gonemaster-submit = {
    description = "Submit gonemaster batch job from the ${tag} tag";
    after = [ "gonemaster-server.service" ];
    requires = [ "gonemaster-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe gonemaster}-client --server http://127.0.0.1:${toString port}/api/v1 jobs batch --from-tag ${tag} --tag ${tag}";
    };
  };

  systemd.timers.gonemaster-submit = {
    description = "Gonemaster batch submission timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = 120;
      Persistent = true;
    };
  };

}
