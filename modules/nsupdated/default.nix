# An RFC 2136 dynamic update and AXFR proxy, backed by any DNSControl
# provider, exposing the provider config as a settings option.
#
# nsupdated performs no authentication of its own: terminate mTLS in front of
# the Unix socket, e.g. with ghostunnel.
{
  config,
  lib,
  pkgs,
  multiverse,
  ...
}:
let
  cfg = config.tomf.nsupdated;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.tomf.nsupdated = {
    enable = lib.mkEnableOption "the nsupdated RFC 2136 proxy";

    package = lib.mkOption {
      type = lib.types.package;
      # nsupdated needs Go 1.27, which the 26.05 channel has not shipped yet
      # (only release candidates); take the final toolchain from the multiverse.
      default = pkgs.callPackage ../../pkgs/nsupdated/package.nix {
        go = multiverse.multiverse.${system}.versions.go_1_27."1.27.0";
      };
      description = "The nsupdated package to use.";
    };

    # Serialized verbatim to the JSON config file.
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        DNSControl provider configuration, written to /etc/nsupdated/creds.json.
        The TYPE field selects the provider; other fields are its credentials.
        Values of the form "$VAR" are replaced with the VAR environment
        variable at runtime, sourced from the service's environment file.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/nsupdated.env";
      description = ''
        Environment file sourcing the secrets referenced from settings. It is
        not managed by NixOS; populate it by hand on the host, e.g. for
        Mythic Beasts:

          MYTHICBEASTS_KEYID=...
          MYTHICBEASTS_SECRET=...
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."nsupdated/creds.json".text = builtins.toJSON cfg.settings;

    systemd.services.nsupdated = {
      description = "nsupdated RFC 2136 proxy";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/nsupdated -listen /run/nsupdated.sock -creds-file /etc/nsupdated/creds.json";
        EnvironmentFile = cfg.environmentFile;
        Restart = "on-failure";
      };
    };
  };
}
