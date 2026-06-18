{
  config,
  pkgs,
  ...
}:

{
  system.stateVersion = "25.11";

  microvm = {
    vcpu = 4;
    mem = 8 * 1024;
    writableStoreOverlay = "/nix/.rw-store";
    registerClosure = false;
    shares = [
      {
        tag = "rw-store";
        source = "/mnt/btrfs/vm/runner/nix";
        mountPoint = "/nix/.rw-store";
        proto = "virtiofs";
      }
    ];
  };

  tomf.sshd = {
    enable = true;
    openFirewall = true;
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.runner = {
      enable = true;
      name = "aluminium-runner";
      url = "https://codeberg.org";
      tokenFile = "/var/lib/gitea-runner/token";
      labels = [
        "native:host"
      ];
    };
  };
}
