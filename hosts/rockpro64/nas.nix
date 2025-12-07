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
    111 # for nfs
    2049 # for nfs
    config.services.nfs.server.mountdPort
  ];

  networking.firewall.allowedUDPPorts = [
    111 # for nfs
    2049 # for nfs
    config.services.nfs.server.mountdPort
  ];

  # Since NFS exposes paths as-is, let's give them short names by bind-mounting them under /export.
  fileSystems."/export/share" = {
    device = "/srv/share/media";
    options = [ "bind" ];
  };

  services.nfs = {
    server = {
      enable = true;
      mountdPort = 4002;
      exports = ''
        	  /export/share -subtree_check \
                                172.17.1.160 \
                                -rw,all_squash,anonuid=${toString config.users.users.share.uid},anongid=${toString config.users.groups.share.gid} \
        			aluminium \
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
