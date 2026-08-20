{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../step-ca/client.nix
  ];

  tomf.step-ca.client.enable = true;

  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.grub.configurationLimit = 15;

  hardware.firmware = [
    pkgs.linux-firmware
  ];

  zramSwap.enable = true;

  nix.gc.automatic = lib.mkDefault true;
  boot.tmp.cleanOnBoot = true;

  # Pull from the tomf-fleet cachix cache.
  nix.settings.extra-substituters = [ "https://tomf-fleet.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "tomf-fleet.cachix.org-1:h9fKL6LcXBgYr7M68A2fuq5xHlUBt/nKFlhLMLw9Rfo="
  ];

  users.users.tom = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      config.security.tpm2.tssGroup
      "wheel"
    ];
    linger = true;
  };

  # Use nftables to support networking.firewall.extraForwardRules.
  networking.nftables.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      btrfs-progs
      cryptsetup
      curl
      dig
      file
      git
      iftop
      mg
      ncdu
      netcat-gnu
      nmap
      nvme-cli
      parted
      pciutils
      picocom
      ripgrep
      smartmontools
      socat
      strace
      tcpdump
      tmux
      tree
      usbutils
    ]
    # No armv7 build: https://github.com/ldc-developers/ldc/issues/3665
    ++ lib.optional (!pkgs.stdenv.hostPlatform.isAarch32) pkgs.btdu
    # No armv7 build: https://github.com/NixOS/nixpkgs/issues/466116
    ++ lib.optional (!pkgs.stdenv.hostPlatform.isAarch32) pkgs.ghostty.terminfo;

  security.tpm2.enable = true;

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
