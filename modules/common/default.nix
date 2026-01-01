{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.grub.configurationLimit = 15;

  hardware.firmware = [
    pkgs.linux-firmware
  ];

  zramSwap.enable = true;

  nix.gc.automatic = lib.mkDefault true;

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Use nftables to support networking.firewall.extraForwardRules.
  networking.nftables.enable = true;
  services.tailscale.enable = true;

  # TODO: Remove if/when comin supports gittuf.
  systemd.timers."fleet-repo-poller" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:0/10:00";
      Persistent = true;
    };
  };

  systemd.services."fleet-repo-poller" = {
    script = ''
      set -eu
      if [ ! -d repo ]; then
          git clone https://codeberg.org/tomf/fleet repo
      fi

      cd repo
      git pull
      git fetch origin refs/gittuf/*:refs/gittuf/*

      gittuf verify-ref master

      cd ..
      rm -rf repo-staging
      cp -r repo repo-staging
      mkdir -p repo-live
      ${pkgs.util-linux}/bin/exch repo-staging repo-live
    '';
    path = [
      pkgs.git
      pkgs.gittuf
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/var/lib/fleet-repo-poller";
      StateDirectory = "fleet-repo-poller";
    };
  };

  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "/var/lib/fleet-repo-poller/repo-live";
        branches.main.name = "master";
        poller.period = 60 * 5; # 5 mins
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    btdu
    btrfs-progs
    cryptsetup
    curl
    dig
    file
    git
    iftop
    ncdu
    netcat-gnu
    nmap
    nvme-cli
    parted
    pciutils
    ripgrep
    smartmontools
    strace
    tcpdump
    tmux
    tree
    usbutils

    ghostty.terminfo
  ];

  networking.hosts = {
    "100.87.189.44" = [ "oxygen" ];
    "100.103.31.75" = [ "aluminium" ];
    "100.94.214.53" = [ "platinum" ];
  };

  programs.ssh = {
    knownHosts = {
      "codeberg.org" = {
        # https://codeberg.org/Codeberg/org/src/commit/c7f344a65ffefd959878b568ec4740946851797e/Imprint.md?display=source#L59
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
      };
      "github.com" = {
        # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
      "gitlab.com" = {
        # https://docs.gitlab.com/ee/user/gitlab_com/index.html#ssh-host-keys-fingerprints
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
      };
      "oncilla.mythic-beasts.com" = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIdfs0v4y4Qt1a2n7qOMtiI1fQPzqqYUqUFKSK0u7Fq";
      };

      # https://nix-community.org/community-builders/
      "build-box.nix-community.org".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElIQ54qAy7Dh63rBudYKdbzJHrrbrrMXLYl7Pkmk88H";
      "aarch64-build-box.nix-community.org".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9uyfhyli+BRtk64y+niqtb+sKquRGGZ87f4YRc8EE1";
    };
  };
}
