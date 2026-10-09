# Optiplex 7070 Micro, a development host.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./rockchip.nix
    ./sunxi.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.05";

  boot = {
    initrd.luks.devices.rootfs = {
      device = "/dev/disk/by-partlabel/disk-main-enc";
      tryEmptyPassphrase = true;
    };
    loader.systemd-boot.enable = true;
  };

  nix.gc.automatic = false; # for dev

  tomf = {
    nfs-client = {
      enable = true;
      wireguard.ips = [ "192.168.2.5/32" ];
      mounts = {
        "/mnt/share" = {
          what = "/export/share";
        };
      };
    };
    remote-builders.enable = true;
    rootfs = {
      device = "/dev/mapper/rootfs";
      subvolume = "/";
    };
    sshd = {
      enable = true;
      openFirewall = true;
    };
    spire = {
      enable = true;
      server = {
        enable = true;
        # Aluminium's WireGuard address, so the mesh agents can reach it.
        bindAddress = "192.168.2.2";
        openFirewall = true;
        nodes = {
          oxygen = {
            ekHash = "c4a5ca47cf839af1ab1edaaece895d1653db23dac47c15c51c31c7c6781d244b";
            users = [ "tom" ];
          };
          aluminium = {
            ekHash = "be64e7af3f8a51c3c62863661cb681bb5121c91b55a33a4ae61564cb63d8db48";
            system-units = [ "ghostunnel" ];
          };
          platinum = {
            ekHash = "d23ac4cfd2e1d98ec105771a142013b0449d2d4a26dad357961c15c583bb6262";
          };
        };
      };
      # Aluminium's own agent provides the SVID for its ghostunnel server.
      agent.enable = true;
    };
    wireguard.enable = true;
  };

  # The server binds aluminium's WireGuard address, so bring the interface up
  # first to avoid a bind failure (and restart loop) at boot.
  systemd.services.spire-server = {
    after = [ "wireguard-wgFleet.service" ];
    wants = [ "wireguard-wgFleet.service" ];
  };

  # SPIFFE-mTLS front-end for sshd. Accepts only a process running as tom on
  # oxygen (spiffe://fleet/oxygen/user/tom) and forwards to the local sshd. The
  # server presents aluminium's own SVID (spiffe://fleet/aluminium/ghostunnel).
  systemd.services.ghostunnel = {
    description = "SPIFFE-mTLS ghostunnel to local sshd";
    wantedBy = [ "multi-user.target" ];
    after = [
      "spire-agent.service"
      "wireguard-wgFleet.service"
    ];
    wants = [ "wireguard-wgFleet.service" ];
    requires = [ "spire-agent.service" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.ghostunnel}/bin/ghostunnel server \
          --use-workload-api-addr unix:///run/spire/agent/public/api.sock \
          --listen 192.168.2.2:2222 \
          --target 127.0.0.1:22 \
          --allow-uri spiffe://fleet/oxygen/user/tom
      '';
      Restart = "on-failure";
      RestartSec = 2;
      DynamicUser = true;
    };
  };

  networking.firewall.interfaces.wgFleet.allowedTCPPorts = [ 2222 ];

  services.udev.packages = [
    pkgs.probe-rs-tools
  ];
  users.groups.plugdev = { };
  users.users.dev = {
    uid = 1001;
    isNormalUser = true;
    extraGroups = [
      config.security.tpm2.tssGroup
      "dialout"
      "plugdev"
    ];
    linger = true;
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGUYYx2b7mHdXTxbnHh3euAUNyn+8aC2J2kOCUmp+JjbwipmjH3MbDjwjCvO7Z89wgVFmw0mL4y7EWucNaZqbKQ= tom@oxygen"
      # cros
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtJLuP7ptqokYFS1U9gskAg4u8wRpTb/jEfJlV7Whab"
    ];
  };

  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."40-wired" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
    };
    # Don't let networkd manage wireguard interfaces; they're managed by
    # the scripted networking wireguard module.
    networks."30-wireguard" = {
      matchConfig.Name = "wg*";
      linkConfig.Unmanaged = "yes";
    };
  };
}
