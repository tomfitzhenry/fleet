{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.grub.configurationLimit = 15;

  hardware.firmware = [
    pkgs.linux-firmware
  ];

  zramSwap.enable = true;

  nix.gc.automatic = lib.mkDefault true;
  boot.tmp.cleanOnBoot = true;

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Use nftables to support networking.firewall.extraForwardRules.
  networking.nftables.enable = true;

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
