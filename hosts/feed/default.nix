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

  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    # Register redirect URIs for both subdomains:
    #   https://<domain1>/oauth2/callback (yarr)
    #   https://<domain2>/oauth2/callback (readeck)
    oidcIssuerUrl = "https://codeberg.org";
    clientID = "11100d5f-6ae4-4334-8d42-d40575e0ab5e";
    clientSecretFile = "/etc/oauth2-proxy/codeberg-client-secret";
    cookie.secretFile = "/etc/oauth2-proxy/cookie-secret";
    email.addresses = "tom@tom-fitzhenry.me.uk";
    # oauth2-proxy is behind Caddy — trust X-Forwarded-* from it.
    reverseProxy = true;
    trustedProxyIP = [ "127.0.0.1" ];
    setXauthrequest = true;
  };

  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      # https://oauth2-proxy.github.io/oauth2-proxy/configuration/integrations/caddy
      (oauth2-proxy-forward) {
        handle /oauth2/* {
          reverse_proxy 127.0.0.1:4180
        }
        handle {
          forward_auth 127.0.0.1:4180 {
            uri /oauth2/auth
            copy_headers Remote-User Remote-Email Remote-Name
            @error status 401
            handle_response @error {
              redir * /oauth2/sign_in?rd={scheme}://{host}{uri}
            }
          }
          reverse_proxy {args[0]}
        }
      }

      import /etc/caddy/vhost.readeck { } {
        import oauth2-proxy-forward 127.0.0.1:${toString config.services.readeck.settings.server.port}
      }
      import /etc/caddy/vhost.yarr { } {
        import oauth2-proxy-forward 127.0.0.1:${toString config.services.yarr.port}
      }
    '';
  };

  services.readeck = {
    enable = true;
    # Needs READECK_SECRET_KEY=
    environmentFile = "/var/lib/readeck/env";
    settings = {
      server.port = 8000;
    };
  };
  services.yarr.enable = true;
}
