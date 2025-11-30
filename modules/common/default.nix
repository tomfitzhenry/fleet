{ pkgs, ... }:
{
  hardware.firmware = [
    pkgs.linux-firmware
  ];

  services.tailscale.enable = true;

  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://codeberg.org/tomf/fleet";
      branches.main.name = "master";
      poller.period = 60*5; # 5 mins
    }];
  };
}
