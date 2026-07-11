{ config, pkgs, ... }: {
  system.stateVersion = "25.05";

  tomf.sshd = {
    enable = true;
    openFirewall = true;
  };

  services.home-assistant.enable = true;
}
