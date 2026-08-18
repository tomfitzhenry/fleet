# A module for OP-TEE and its PKCS#11 token.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.op-tee;
in
{
  options = {
    tomf.op-tee = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      platform = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      optee = pkgs.buildOptee {
        platform = cfg.platform;
        extraMeta.platforms = [ "aarch64-linux" ];
      };
    in
    {
      services.tee-supplicant = {
        enable = true;
        trustedApplications = [
          # pkcs11: https://github.com/OP-TEE/optee_os/blob/b07792026058b027e79573373d8b068d2e7a8bb9/ta/pkcs11/user_ta.mk#L1
          "${optee.devkit}/ta/fd02c9da-306c-48c7-a49c-bbd827ae86ee.ta"
        ];
      };

      # The kernel creates /dev/tee0 and /dev/teepriv0 as root:root 0600.
      # Grant users (tom) the client device; teepriv0 stays root-only (it's
      # tee-supplicant's privileged channel).
      services.udev.extraRules = ''KERNEL=="tee0", MODE="0660", GROUP="tee"'';

      users.groups.tee = { };
      users.users.tom.extraGroups = [ "tee" ];

      environment.systemPackages = [
        # pkcs11-tool --module libckteec.so to use the OP-TEE PKCS#11 token.
        pkgs.opensc
        pkgs.optee-client
        pkgs.optee-client.lib
      ];
    }
  );
}
