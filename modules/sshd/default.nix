# A module for managing sshd.
{ lib, config, ... }:
let
  cfg = config.tomf.sshd;
  keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA13oQrkygCx4G9HVeIjdItLtpZUmS2ICjMfmD0GPeGjAAAABHNzaDo= oxygen-sk"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICpd1nSXGyN375CCLYmHH3VvhsqRTTJO3eS2vdBL/702AAAABHNzaDo= portable-yubikey"
  ];
in
{
  options = {
    tomf.sshd = {
      enable = lib.mkOption {
        type = lib.types.bool;
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = cfg.openFirewall;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    users.users.tom.openssh.authorizedKeys.keys = keys;
    users.users.root.openssh.authorizedKeys.keys = keys;
  };
}
