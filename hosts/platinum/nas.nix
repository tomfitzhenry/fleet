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
    "/export/fastnas" = {
      device = "/srv/fastnas";
      fsType = "none";
      options = [ "bind" ];
    };
  };

  networking.firewall = {
    interfaces.wgFleet = {
      allowedTCPPorts = [
        2049 # nfs
      ];
    };

    extraInputRules = ''
      ip saddr 172.17.1.176 tcp dport 2049 comment "PS4 Netboot" accept comment "PS4 Netboot"
    '';
  };

  services.nfs = {
    server = {
      enable = true;
      exports = ''
        /export/share \
                      -rw,all_squash,anonuid=${toString config.users.users.share.uid},anongid=${toString config.users.groups.share.gid} \
                      aluminium-nfs \
                      oxygen-nfs
        /export/tom -subtree_check,rw \
                    oxygen-nfs
        # The PS4's netboot rootfs tree. Lives on the fast root filesystem, not
        # the HDD array: sync writes over NFS to the spinning array made package
        # installation unusably slow. async is fine for a disposable netboot
        # root. no_root_squash so the client's root can write as root.
        /export/fastnas/ps4 \
                      -rw,no_root_squash,async \
                      172.17.1.176
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
