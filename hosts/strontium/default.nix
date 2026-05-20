# An IPv6-only VM from iFog
# https://v6only.ch/
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.system = "x86_64-linux";
  networking.hostName = "strontium";
  system.stateVersion = "25.04";

  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
    "earlyprintk=ttyS0,115200"
    "consoleblank=0"
  ];

  boot.loader.grub = {
    device = "/dev/sda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/disk/by-uuid/212006ad-c976-4a1e-ac3b-a7f83ea52de7";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    wireguard.enable = true;
  };

  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks = {
      ens18 = {
        matchConfig = {
          Name = "ens18";
        };
        networkConfig = {
          Address = [
            "2a0c:9a40:2510:1001::10eb/64"
          ];
          Gateway = "2a0c:9a40:2510:1001::1";
          DNS = [
            "2606:4700:4700::1111"
          ];
        };
      };
    };
  };

  # This machine is IPv6-only, so let's provide connectivity via a public NAT64 gateway.
  services.clatd = {
    enable = true;
    # https://nat64.xyz/
    # https://level66.services/services/nat64/
    settings.plat-prefix = "2001:67c:2960:6464::/96";
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
  services.knot = {
    enable = true;
    settings = {
      server = {
        listen = "::";

        # Listen on TLS for mTLS-authenticated DNS UPDATEs.
        # TODO: Permit mTLS to Knot DNS over public Internet, if/when that seems sane.
        #
        # $ knotc status cert-key
        # public key pin: 60VI3zVqodGsKHT7q1c3KcWkmbAxh7VgR4+0YFhY6qo=
        listen-tls = "::1";
      };
      template = [
        {
          id = "member_template";
          acl = [
            "mtls"
            "he-slave"
            "ns-global"
            "puck"
          ];
          notify = [
            "he-ns1"
            "ns-global"
            "puck"
          ];
        }
      ];
      zone = [
        # A catalog zone. This allows the creation/deletion of zones via DNS UPDATE.
        # https://www.knot-dns.cz/docs/latest/html/configuration.html#catalog-zones
        {
          domain = "catz.";
          catalog-role = "interpret";
          catalog-template = "member_template";
          acl = "mtls";
        }
      ];
      remote = [
        {
          id = "he-ns1";
          address = [
            # ns1.he.net
            "2001:470:100::2"
          ];
        }
        {
          # https://ns-global.zone
          id = "ns-global";
          address = [
            "2607:7c80:54:6::53"
          ];
        }
        {
          # https://puck.nether.net/dns/
          id = "puck";
          address = [
            "2602:fe55:5::5"
          ];
        }
      ];
      acl = [
        {
          id = "mtls";
          # TODO: Permit mTLS to Knot DNS over public Internet, if/when that seems sane.
          address = "::1";
          protocol = [
            "tls"
          ];
          # $ openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -nodes -keyout ecdsa_key.pem -out ecdsa_cert.pem -subj "/CN=localhost"
          # $ openssl x509 -in ecdsa_cert.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | openssl enc -base64
          cert-key = "6/VMy2HFtqft/uGCXdq7kneLoGqX6d1XoGszv+1L/hc=";
          action = [
            # $ kdig @127.0.0.1 -p 8853 -t AXFR $DOMAIN +tls-certfile=ecdsa_cert.pem +tls-keyfile=ecdsa_key.pem +tls-pin=60VI3zVqodGsKHT7q1c3KcWkmbAxh7VgR4+0YFhY6qo=
            "transfer"

            # $ knsupdate -p 8853 --tls --pin 60VI3zVqodGsKHT7q1c3KcWkmbAxh7VgR4+0YFhY6qo= --certfile ecdsa_cert.pem --keyfile ecdsa_key.pem
            "update"
          ];
        }
        {
          id = "he-slave";
          address = [
            # slave.dns.he.net
            "2001:470:600::2"
          ];
          action = [
            "transfer"
          ];
        }
        {
          # Allow ns-global to AXFR.
          id = "ns-global";
          address = [
            # https://ns-global.zone/signup/
            "2607:7c80:54:6::53"
          ];
          action = "transfer";
        }
        {
          # Allow puck.nether.net to AXFR.
          id = "puck";
          address = [
            # https://puck.nether.net/dns/static/faq.html
            "2602:fe55:5::5"
          ];
          action = "transfer";
        }
      ];
    };
  };
}
