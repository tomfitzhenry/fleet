# A Radicle seed node. https://radicle.dev
{
  config,
  lib,
  ...
}:
let
  cfg = config.tomf.radicle-node;
in
{
  options.tomf.radicle-node = {
    enable = lib.mkEnableOption "Radicle seed node";
    publicKey = lib.mkOption {
      type = lib.types.str;
      description = ''
        The node's SSH public key, from `rad auth`. Unlike other SSH keys,
        radicle's node key must not have a comment, and differs per host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.radicle = {
      enable = true;
      inherit (cfg) publicKey;
      privateKey = "/etc/radicle-node/node.key";
      settings = {
        node.alias = config.networking.hostName;
        web.pinned.repositories = [
          "rad:z3BvgcWWXAKMg8Rd8vBqPFE4gmw4z" # dotfiles
          "rad:z24mzhKEoMoZYtkpRE294sLswEDpu" # nix-embedded-static-binaries
        ];
      };
    };
  };
}
