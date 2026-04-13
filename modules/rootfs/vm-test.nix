# NixOS VM test for the rootfs module.
{ ... }:
let
  label = "ROOTFS";
  device = "/dev/disk/by-label/${label}";
in
{
  name = "rootfs";

  nodes.machine =
    {
      pkgs,
      lib,
      ...
    }:
    {
      virtualisation = {
        emptyDiskImages = [ 2048 ];
        useBootLoader = true;
        useEFIBoot = true;
        mountHostNixStore = true;
      };

      boot.loader.systemd-boot.enable = true;

      environment.systemPackages = with pkgs; [ btrfs-progs ];

      specialisation.boot-btrfs.configuration = {
        imports = [ ./. ];

        tomf.rootfs = {
          device = device;
          subvolume = "/root";
        };

        virtualisation.fileSystems = lib.mkForce { };
        virtualisation.useDefaultFilesystems = false;

        # Re-add nix store mounts (removed by mkForce above)
        fileSystems."/nix/.ro-store" = {
          device = "nix-store";
          fsType = "9p";
          neededForBoot = true;
          options = [
            "trans=virtio"
            "version=9p2000.L"
            "cache=loose"
            "ro"
          ];
        };
        fileSystems."/nix/store" = {
          device = "/nix/.ro-store";
          fsType = "none";
          options = [ "bind" ];
        };
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Create btrfs filesystem and root subvolume
    machine.succeed("mkfs.btrfs -f -L ${label} /dev/vdb")
    machine.succeed("mkdir -p /mnt/setup")
    machine.succeed("mount /dev/vdb /mnt/setup")
    machine.succeed("btrfs subvolume create /mnt/setup/root")
    machine.succeed("umount /mnt/setup")

    # Reboot into btrfs specialisation
    machine.succeed("bootctl set-default nixos-generation-1-specialisation-boot-btrfs.conf")
    machine.succeed("sync")
    machine.crash()

    machine.wait_for_unit("multi-user.target")

    # Verify root is btrfs
    machine.succeed("findmnt -n -o FSTYPE / | grep -q btrfs")

    # Verify btrbk creates snapshots
    machine.succeed("systemctl start btrbk-root.service")
    machine.succeed("btrfs subvolume list /mnt/btrfs | grep -q 'snapshots/root'")
  '';
}
