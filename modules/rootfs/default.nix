# A module that manages the rootfs.
{ config, lib, ... }:
let
  cfg = config.tomf.rootfs;
in
{
  options = {
    tomf.rootfs = {
      device = lib.mkOption {
	type = lib.types.str;
      };
      subvolume = lib.mkOption {
	type = lib.types.str;
      };
    };
  };

  config = {
    fileSystems = {
      "/" = {
	device = cfg.device;
	fsType = "btrfs";
	options = [
	  ("subvol=" + cfg.subvolume)
	];
	neededForBoot = true;
      };

      # A mountpoint guaranteed to be the root of the btrfs partition, since / might be a subvolume.
      "/mnt/btrfs" = {
	device = cfg.device;
	fsType = "btrfs";
	options = [
	  "compress=zstd"
	];
	neededForBoot = true;
      };
    };

    systemd.services."create-directories" = {
      script = ''
        cd /mnt/btrfs
        mkdir -p snapshots/root
      '';
      wantedBy = [ "multi-user.target" ];
    };

    services.btrbk = {
      instances = {
        "root" = {
          settings = {
            snapshot_preserve = "20d 10w *m";
            snapshot_preserve_min = "2d";
            subvolume = "/mnt/btrfs" + cfg.subvolume;
            snapshot_dir = "/mnt/btrfs/snapshots/root";
          };
          onCalendar = "*-*-* *:00:00";
        };
      };
    };
  };
}
