{ config, pkgs, ... }: {
  system.stateVersion = "25.05";

  tomf.sshd = {
    enable = true;
    openFirewall = true;
  };

  # This machine is IPv6-only, so let's provide connectivity via a public NAT64 gateway.
  # TODO: Replace with my own NAT64 gateway.
  services.clatd = {
    enable = true;
    # https://nat64.xyz/
    # https://level66.services/services/nat64/
    settings.plat-prefix = "2001:67c:2960:6464::/96";
  };

  networking.firewall.allowedTCPPorts = [ 443 ];

  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      import /etc/caddy/vhost { } {
        basic_auth {
          tom $2a$14$w.rkYXmgon7phJLm.6689OT9w0iGqkXbM6f9huI7YBJUDlHq5tY5y
        }
        reverse_proxy 127.0.0.1:${toString config.services.yarr.port}
      }
    '';
  };

  services.yarr.enable = true;
}
