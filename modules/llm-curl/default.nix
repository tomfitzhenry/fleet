# Shadow a user's curl with llm-curl, which serves source-code URLs from local
# git clones under ~/src instead of the network. The real curl stays available
# as real-curl. https://github.com/tomfitzhenry/llm-curl
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.llm-curl;

  # A user-profile package shadowing curl for this user. llm-curl locates the
  # real curl by skipping its own symlink while scanning PATH, so pointing curl
  # at the llm-curl binary is all the wiring it needs.
  shadow = pkgs.runCommand "llm-curl-shadow" { } ''
    mkdir -p $out/bin
    ln -s ${cfg.package}/bin/llm-curl $out/bin/curl
    ln -s ${lib.getExe pkgs.curl} $out/bin/real-curl
  '';
in
{
  options.tomf.llm-curl = {
    enable = lib.mkEnableOption "llm-curl as a drop-in curl for a user";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose curl should be shadowed by llm-curl.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/llm-curl/package.nix { };
      description = "The llm-curl package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user}.packages = [ shadow ];
  };
}
