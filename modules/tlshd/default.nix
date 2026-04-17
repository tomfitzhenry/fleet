# A module for managing tlshd.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.tomf.tlshd;
in
{
  options = {
    tomf.tlshd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      settings = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        description = ''
          Configuration for tlshd in INI format.
          See {manpage}`tlshd.conf(5)` for available options.
        '';
      };
    };
  };
  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tls" ];

    system.services.tlshd = {
      imports = [ (lib.modules.importApply ../../pkgs/ktls-utils/service.nix { }) ];
      tlshd.package = pkgs.ktls-utils;
      tlshd.settings = cfg.settings;
    };
  };
}
