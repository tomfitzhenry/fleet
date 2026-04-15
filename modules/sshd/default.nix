# A module for managing sshd.
{ lib, config, ... }:
let
  cfg = config.tomf.sshd;
  keys = [
    # Yubikey serial 13834265
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA13oQrkygCx4G9HVeIjdItLtpZUmS2ICjMfmD0GPeGjAAAABHNzaDo= oxygen-sk"
    # Yubikey serial 10574875
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICpd1nSXGyN375CCLYmHH3VvhsqRTTJO3eS2vdBL/702AAAABHNzaDo= portable-yubikey"
    # Yubikey serial 11120573
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIN3Je4I0D9gf6krw+HhM5X0Fdg1sq5bf3VDvLBDxZ3XAAAAABHNzaDo= ozdesk-sk"
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
      authorizedKeysInHomedir = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;

        # Avoid closing connections from suspended laptops.
        TCPKeepAlive = false;
      };
    };

    users.users.tom.openssh.authorizedKeys.keys = keys;
    users.users.root.openssh.authorizedKeys.keys = keys;
  };
}
