# A localhost-only outbound SMTP relay using OpenSMTPD. Local tools submit via
# the sendmail shim; a builtin filter rewrites every recipient to the
# notification address, so only mail to that address can leave the host.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.mail-relay;
  # smtpctl execs cat(1)/gzcat(1) from non-NixOS paths.
  opensmtpd = pkgs.opensmtpd.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace usr.sbin/smtpd/smtpctl.c \
        --replace-fail '"/bin/cat"' '"${pkgs.coreutils}/bin/cat"' \
        --replace-fail '"/usr/bin/gzcat"' '"${pkgs.gzip}/bin/zcat"'
    '';
  });
in
{
  options = {
    tomf.mail-relay = {
      enable = lib.mkEnableOption "the localhost-only outbound SMTP relay";
      hostname = lib.mkOption {
        type = lib.types.str;
        description = ''
          Domain used for the outbound HELO when relaying, and so the domain
          that SPF should authorise this host to send as, e.g. "v=spf1 a ~all".
        '';
      };
      recipient = lib.mkOption {
        type = lib.types.str;
        description = "Address to forward all submitted mail to.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.opensmtpd = {
      enable = true;
      package = opensmtpd;
      # Rewrite every RCPT TO to the notification address. `!auth` (always
      # true here) matches every submission, since a filter can't have no
      # conditions.
      serverConfiguration = ''
        filter "forward" phase rcpt-to match !auth rewrite "<${cfg.recipient}>"

        listen on socket filter "forward"

        action "outbound" relay helo ${cfg.hostname}

        match from local for any action "outbound"
      '';
    };

    # Qualify bare From headers (e.g. smartd's "root") with the relay domain.
    environment.etc.mailname.text = cfg.hostname;
  };
}
