# NixOS VM test for the btrfs-health module. Two btrfs filesystems are created
# and mounted in the testScript (a test VM cannot declare extra fileSystems
# alongside its root, so the nixpkgs convention is to mount manually), and
# auto-discovery picks them up. We assert that problems produce an email
# (captured by a fake sendmail) and that a healthy array stays silent.
{ pkgs, ... }:
let
  # Captures whatever the health check would send via sendmail.
  capture-mailer = pkgs.writeShellScript "capture-sendmail" ''
    cat >> /tmp/btrfs-health-mail
  '';
in
{
  name = "btrfs-health";

  nodes.host =
    { ... }:
    {
      imports = [
        ./.
        ../mail-relay
      ];

      # btrfs-health sends via the sendmail shim, so it needs the relay enabled;
      # the mailer override below captures the report for assertions.
      tomf.mail-relay = {
        enable = true;
        hostname = "test.invalid";
        recipient = "root@test.invalid";
      };

      tomf.btrfs-health = {
        enable = true;
        mailer = capture-mailer;
      };

      boot.supportedFilesystems = [ "btrfs" ];
      environment.systemPackages = [ pkgs.btrfs-progs ];
      virtualisation.emptyDiskImages = [
        # Smaller disks leave almost no unallocated space after mkfs allocates
        # metadata chunks, which would trip the ENOSPC-risk check spuriously.
        1024
        1024
      ];
    };

  testScript = ''
    host.wait_for_unit("multi-user.target")

    host.succeed("mkfs.btrfs -f /dev/vdb")
    host.succeed("mkfs.btrfs -f /dev/vdc")
    host.succeed("mkdir -p /srv/share /srv/second")
    host.succeed("mount /dev/vdb /srv/share")
    host.succeed("mount /dev/vdc /srv/second")

    # No scrub has ever run: both filesystems are reported.
    host.succeed("systemctl start btrfs-health.service")
    mail = host.succeed("cat /tmp/btrfs-health-mail")
    assert "scrub" in mail, mail

    # After a successful scrub there is nothing to report.
    host.succeed("btrfs scrub start -B /srv/share")
    host.succeed("btrfs scrub start -B /srv/second")
    host.succeed("rm -f /tmp/btrfs-health-mail")
    host.succeed("systemctl start btrfs-health.service")
    host.succeed("test ! -e /tmp/btrfs-health-mail")

    # A scrub that ran long ago is reported.
    host.succeed(
      "find /var/lib/btrfs -name 'scrub.status.*' -exec touch -d '60 days ago' {} +")
    host.succeed("systemctl start btrfs-health.service")
    mail = host.succeed("cat /tmp/btrfs-health-mail")
    assert "too old" in mail, mail
  '';
}
