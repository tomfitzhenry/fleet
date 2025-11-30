{ pkgs, ... }:
{
  hardware.firmware = [
    pkgs.linux-firmware
  ];

  services.tailscale.enable = true;
}
