# Optiplex 7070 Micro, a VM host.
{ pkgs, lib, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-enc";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

  tomf = {
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
  };

  virtualisation.podman.enable = true;

  # Connect with "screen /dev/pts/1"
  systemd.services.vm-alma = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip link del vm-alma || true'"
        "${pkgs.iproute2}/bin/ip link add link eno2 name vm-alma type macvtap"
        "${pkgs.iproute2}/bin/ip link set vm-alma address 6a:c8:f1:8d:78:c1 up"
        "${pkgs.iproute2}/bin/ip link set vm-alma up"
      ];
      ExecStart = "${lib.getExe pkgs.bash} -c '${lib.getExe pkgs.cloud-hypervisor} --disk path=/srv/vm/alma.raw --memory size=4G --firmware /srv/vm/hypervisor-fw --serial pty --console off --net fd=3,mac=$(cat /sys/class/net/vm-alma/address) 3<>/dev/tap$(cat /sys/class/net/vm-alma/ifindex)' --cmdline console=hvc0";
      Restart = "always";
    };
  };
}
