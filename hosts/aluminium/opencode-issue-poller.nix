# Runs the opencode issue poller for dev. The poller is a long-running loop
# that only exits on error, so systemd restarts it on failure.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  systemd.user.services.opencode-issue-poller = {
    description = "Poll opencode issues";
    wantedBy = [ "default.target" ];
    # NixOS installs user units globally in /etc/systemd/user, so restrict this
    # one to dev by testing the user manager's own user (ConditionUser, systemd
    # >= 244). dev's user manager starts at boot because of linger.
    unitConfig.ConditionUser = "dev";
    # NixOS user units default to a minimal PATH (coreutils, ...) that shadows
    # the user manager's; drop it so the unit inherits dev's profile PATH
    # (via /etc/environment.d/50-systemd-path.conf), where gh/opencode/jq live.
    enableDefaultPath = false;
    serviceConfig = {
      # Run the working copy rather than a nix store path: the script is under
      # active development.
      ExecStart = "/home/dev/src/robotfleet/scripts/opencode-issue-poller.sh";
      WorkingDirectory = "/home/dev/robotfleet";
      Restart = "on-failure";
      RestartSec = 30;
    };
  };
}
