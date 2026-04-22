{ config, ... }:
{
  users.users.share = {
    uid = 1021;
    group = "share";
    isSystemUser = true;
  };

  users.groups.share = {
    gid = 1021;
  };

  networking.firewall.allowedTCPPorts = [
    2222
  ];

  # Since NFS exposes paths as-is, let's give them short names by bind-mounting them under /export.
  fileSystems = {
    "/export/share" = {
      device = "/srv/share/media";
      fsType = "none";
      options = [ "bind" ];
    };
    "/export/tom" = {
      device = "/srv/share/tom";
      fsType = "none";
      options = [ "bind" ];
    };
  };

  tomf.tlshd = {
    enable = true;
    settings = {
      "authenticate.server" = {
        "x509.certificate" = "/var/lib/tlshd/cert.pem";
        "x509.private_key" = "/var/lib/tlshd/key.pem";
        "x509.truststore" = "/var/lib/tlshd/truststore.pem";
      };
    };
  };

  networking.firewall = {
    interfaces.wgFleet = {
      allowedTCPPorts = [
        2049 # nfs
      ];
    };
  };

  services.nfs = {
    server = {
      enable = true;
      hostName = "192.168.2.3"; # wireguard address
      exports = ''
        /export/share \
                      -rw,all_squash,anonuid=${toString config.users.users.share.uid},anongid=${toString config.users.groups.share.gid},xprtsec=mtls \
                      aluminium \
                      oxygen
        /export/tom -subtree_check,rw,xprtsec=mtls \
                      oxygen
        	'';
    };
  };
  services.btrbk = {
    instances = {
      "share" = {
        settings = {
          snapshot_preserve = "20d 10w *m";
          snapshot_preserve_min = "2d";
          subvolume = "/srv/share";
          snapshot_dir = "/srv/share/snapshots";
        };
        # Beware that taking a snapshot spins up the disks.
        onCalendar = "*-*-* 00/4:00:00";
      };
    };
  };
}
