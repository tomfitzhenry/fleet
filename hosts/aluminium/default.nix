# Optiplex 7070 Micro, a VM/container host.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./jellyfin.nix
    ./microvm-host.nix
    ../../modules/llm-curl
    ../../modules/mail-relay
    ../../modules/nsupdated
    ../../modules/step-ca
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
    mail-relay = {
      enable = true;
      hostname = "al.h.tom-fitzhenry.me.uk";
      recipient = "tom@tom-fitzhenry.me.uk";
    };
    nsupdated = {
      enable = true;
      settings = {
        TYPE = "MYTHICBEASTS";
        keyID = "$MYTHICBEASTS_KEYID";
        secret = "$MYTHICBEASTS_SECRET";
      };
    };
    llm-curl = {
      enable = true;
      user = "dev";
    };
    podman.enable = true;
    radicle-node = {
      enable = true;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHrBcb0XDIRmMceUi9gUAPNxwAETFON1eBcKhasurmTq";
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
    step-ca.enable = true;
    wireguard.enable = true;
  };

  # Monitor disk health, and email alerts via the mail relay. Notifications go
  # to the default (root); the relay's aliases forward them on.
  services.smartd = {
    enable = true;
    notifications.mail.enable = true;
  };

  boot.kernel.sysctl = {
    # Allow non-privileged Podman containers to listen on 443/tcp.
    "net.ipv4.ip_unprivileged_port_start" = 443;
    # Forward traffic to microVMs.
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.firewall.allowedTCPPorts = [
    443 # https
  ];

  networking.firewall.interfaces.wgFleet.allowedTCPPorts = [
    1883
  ];

  users.users.podman.extraGroups = [
    "render" # hw acceleration
  ];

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

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  # A Hercules CI agent. https://hercules-ci.com
  # The agent authenticates to hercules-ci.com with a cluster join token, which
  # is a secret and is not stored in the repository (ARCHITECTURE.md); install
  # it by hand on this host:
  #
  #   install -d -m 0700 -o hercules-ci-agent -g hercules-ci-agent \
  #     /var/lib/hercules-ci-agent/secrets
  #   install -m 0400 -o hercules-ci-agent -g hercules-ci-agent \
  #     <token-file> /var/lib/hercules-ci-agent/secrets/cluster-join-token.key
  #
  # The cluster join token comes from https://hercules-ci.com/dashboard. To
  # push builds to a cache later, replace binaryCachesPath with a
  # binary-caches.json in the secrets directory (see
  # https://docs.hercules-ci.com/hercules-ci-agent/binary-caches-json/).
  services.hercules-ci-agent = {
    enable = true;
    settings = {
      # A single agent works without a binary cache.
      binaryCachesPath = "${pkgs.writeText "binary-caches.json" "{}"}";
      concurrentTasks = 4;
      remotePlatformsWithSameFeatures = [
        "aarch64-linux"
        "armv7l-linux"
      ];
      # Allow CI to target jobs at this host.
      labels.host = "aluminium";
    };
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
