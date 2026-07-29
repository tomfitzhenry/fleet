{ config, pkgs, ... }:
let
  openobservePort = 5080;
in
{
  imports = [ ./gonemaster.nix ];

  system.stateVersion = "25.05";

  tomf = {
    otel-collector.enable = true;
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

  services.opentelemetry-collector.settings = {
    receivers.prometheus.config.scrape_configs = [
      {
        job_name = "caddy";
        scrape_interval = "60s";
        static_configs = [ { targets = [ "127.0.0.1:2019" ]; } ];
      }
      {
        job_name = "gonemaster";
        scrape_interval = "60s";
        metrics_path = "/api/v1/metrics";
        params = {
          format = [ "prom" ];
        };
        static_configs = [ { targets = [ "127.0.0.1:9117" ]; } ];
      }
    ];
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
      {
        servers {
          metrics
        }
        metrics {
          per_host
        }
      }
      import /etc/caddy/vhost.openobserve { } {
        # These credentials are forwarded to OpenObserve.
        # TODO: Find a better way to reverse proxy OpenObserve.
        basic_auth {
          # Admin login. Password must match the OpenObserve's root user.
          tom $2a$14$w.rkYXmgon7phJLm.6689OT9w0iGqkXbM6f9huI7YBJUDlHq5tY5y

          # Log ingestion; password is an OpenObserve service-account API
          # token (IAM > Service Accounts).
          otel@example.com $2a$14$Fez.nNVwOGTCbTkriX9vOe80/bZjCqRjweQPLs7cuZd/nyQxMa7tK
        }
        reverse_proxy 127.0.0.1:${toString openobservePort}
      }
      import /etc/caddy/vhost.gatus { } {
        basic_auth {
          tom $2a$14$w.rkYXmgon7phJLm.6689OT9w0iGqkXbM6f9huI7YBJUDlHq5tY5y
        }
        reverse_proxy 127.0.0.1:8043
      }
    '';
  };

  services.gatus = {
    enable = true;
    configFile = "/etc/gatus/config.yaml";
  };

  systemd.services.openobserve = {
    description = "OpenObserve";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      ZO_DATA_DIR = "/var/lib/openobserve/data";
      ZO_HTTP_ADDR = "127.0.0.1";
      ZO_HTTP_PORT = toString openobservePort;
      # OpenObserve logs verbosely at INFO.
      RUST_LOG = "warn";
    };
    serviceConfig = {
      ExecStart = "${pkgs.openobserve}/bin/openobserve";
      # Expects ZO_ROOT_USER_EMAIL and ZO_ROOT_USER_PASSWORD.
      EnvironmentFile = "/var/lib/openobserve/env";
      DynamicUser = true;
      StateDirectory = "openobserve";
      Restart = "on-failure";
    };
  };
}
