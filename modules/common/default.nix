{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.grub.configurationLimit = 15;

  hardware.firmware = [
    pkgs.linux-firmware
  ];

  nix.gc.automatic = lib.mkDefault true;

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  services.tailscale.enable = true;

  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://codeberg.org/tomf/fleet";
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
    netcat-gnu
    strace
    tcpdump
    usbutils
  ];

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
    };
  };
}
