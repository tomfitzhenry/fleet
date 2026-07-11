{ config, pkgs, ... }: {
  system.stateVersion = "25.05";

  tomf.sshd = {
    enable = true;
    openFirewall = true;
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
