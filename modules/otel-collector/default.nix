{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.otel-collector;
in
{
  options.tomf.otel-collector = {
    enable = lib.mkEnableOption "OpenTelemetry collector";
  };

  config = lib.mkIf cfg.enable {
    services.opentelemetry-collector = {
      enable = true;
      package = pkgs.opentelemetry-collector-contrib;
      settings = {
        telemetry.metrics.address = "localhost:8888";

        receivers = {
          hostmetrics = {
            scrapers = {
              cpu = { };
              disk = { };
              filesystem = { };
              memory = { };
              network = { };
            };
          };
          journald = { };
          prometheus.config.scrape_configs = [
            {
              job_name = "opentelemetry-collector";
              scrape_interval = "60s";
              static_configs = [ { targets = [ "localhost:8888" ]; } ];
            }
          ];
        };

        processors = {
          batch.timeout = "60s";
          resourcedetection.detectors = [
            # Tag each batch with host.name so logs are attributable per host.
            "system"
          ];
        };

        exporters.otlphttp = {
          logs_endpoint = "\${env:OTEL_DOMAIN}/api/default/v1/logs";
          metrics_endpoint = "\${env:OTEL_DOMAIN}/api/default/v1/metrics";
          headers.Authorization = "\${env:OTEL_AUTH_HEADER}";
        };

        service.pipelines.logs = {
          receivers = [ "journald" ];
          processors = [
            "resourcedetection"
            "batch"
          ];
          exporters = [ "otlphttp" ];
        };

        service.pipelines.metrics = {
          receivers = [
            "hostmetrics"
            "prometheus"
          ];
          processors = [
            "resourcedetection"
            "batch"
          ];
          exporters = [ "otlphttp" ];
        };
      };
    };

    systemd.services.opentelemetry-collector = {
      # The journald receiver shells out to journalctl.
      path = [ pkgs.systemd ];

      # Environment variables that must be in this file:
      #
      # OTEL_AUTH_HEADER=Basic <base64 of "SERVICE_ACCOUNT_EMAIL:TOKEN">
      # OTEL_DOMAIN=https://example.com
      #
      serviceConfig.EnvironmentFile = "/etc/otel-collector.env";
    };
  };
}
