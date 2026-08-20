# A self-hosted ACME certificate authority using step-ca, modelled on
# https://github.com/Mic92/dotfiles/tree/main/machines/eve/modules/step-ca
#
# step-ca terminates its own TLS (on the configured port) and issues
# certificates via its ACME provisioner; clients prove control of their names
# with HTTP-01 on their own hosts.
#
# On first boot the root and intermediate CAs are generated into
# /var/lib/step-ca/. Export the root certificate to modules/step-ca/root_ca.crt
# (see client.nix) so fleet hosts can trust certificates issued by this CA:
#
#   curl -k https://ca.tom-fitzhenry.me.uk/roots.pem -o modules/step-ca/root_ca.crt
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.step-ca;
  domain = cfg.domain;
  # The intermediate CA may only issue certificates for names under this
  # domain (RFC 5280 name constraints).
  permittedDomain = lib.concatStringsSep "." (lib.tail (lib.splitString "." domain));
  rootTemplate = pkgs.writeText "root-ca.tmpl" ''
    {
      "subject": {{ toJson .Subject }},
      "issuer": {{ toJson .Subject }},
      "keyUsage": ["certSign", "crlSign"],
      "basicConstraints": {
        "isCA": true,
        "maxPathLen": 1
      }
    }
  '';
  intermediateTemplate = pkgs.writeText "intermediate-ca.tmpl" ''
    {
      "subject": {{ toJson .Subject }},
      "keyUsage": ["certSign", "crlSign"],
      "basicConstraints": {
        "isCA": true,
        "maxPathLen": 0
      },
      "nameConstraints": {
        "critical": true,
        "permittedDNSDomains": ["${permittedDomain}"]
      }
    }
  '';
in
{
  options = {
    tomf.step-ca = {
      enable = lib.mkEnableOption "the self-hosted step-ca ACME CA";
      domain = lib.mkOption {
        type = lib.types.str;
        default = "ca.tom-fitzhenry.me.uk";
      };
      # step-ca terminates TLS on this address/port. The wildcard binds both
      # stacks, so the CA is reachable over IPv6 (its DNS only has an AAAA).
      address = lib.mkOption {
        type = lib.types.str;
        default = "[::]";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services.step-ca = {
      enable = true;
      address = cfg.address;
      port = cfg.port;
      settings = {
        root = "/var/lib/step-ca/root_ca.crt";
        crt = "/var/lib/step-ca/intermediate_ca.crt";
        key = "/var/lib/step-ca/intermediate_ca.key";
        dnsNames = [ domain ];
        logger.format = "text";
        db = {
          type = "badger";
          dataSource = "/var/lib/step-ca/db";
        };
        authority = {
          provisioners = [
            {
              type = "ACME";
              name = "acme";
              forceCN = true;
            }
          ];
          claims = {
            maxTLSCertDuration = "2160h";
            defaultTLSCertDuration = "2160h";
          };
          backdate = "1m0s";
        };
      };
    };

    # Bootstrap the root and intermediate CAs on first boot.
    systemd.services.step-ca = {
      path = [
        pkgs.step-cli
        pkgs.coreutils
      ];
      preStart = ''
        root=/var/lib/step-ca/root_ca.crt
        if [ ! -f "$root" ]; then
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT

          step certificate create \
            --template ${rootTemplate} \
            "Tom Fitzhenry Root CA" \
            "$tmp/root_ca.crt" "$tmp/root_ca.key" \
            --kty EC --curve P-256 \
            --not-after 87600h \
            --no-password --insecure

          step crypto keypair \
            --kty EC --curve P-256 --no-password --insecure \
            "$tmp/intermediate_ca.pub" "$tmp/intermediate_ca.key"

          step certificate create \
            --ca "$tmp/root_ca.crt" \
            --ca-key "$tmp/root_ca.key" \
            --ca-password-file /dev/null \
            --key "$tmp/intermediate_ca.key" \
            --template ${intermediateTemplate} \
            --not-after 8760h \
            --no-password --insecure \
            "Tom Fitzhenry Intermediate CA" \
            "$tmp/intermediate_ca.crt"

          install -m 0644 "$tmp/root_ca.crt" /var/lib/step-ca/root_ca.crt
          install -m 0644 "$tmp/intermediate_ca.crt" /var/lib/step-ca/intermediate_ca.crt
          install -m 0600 "$tmp/intermediate_ca.key" /var/lib/step-ca/intermediate_ca.key
        fi
      '';
    };
  };
}
