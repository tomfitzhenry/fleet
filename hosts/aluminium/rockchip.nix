# Rockchip rockusb development (Pine64 QuartzPro64, RK3588, over USB).
#
# The RK3588 boot ROM's maskrom mode enumerates as USB 2207:350b, and the
# loader that `rkdeveloptool db` uploads keeps that same VID:PID (rkdeveloptool
# tells maskrom from loader by bcdUSB bit 0, not by product ID). rkdeveloptool
# drives the raw USB node with libusb, which the default root:root 0664 denies,
# and there is no stock udev rule for vendor 2207. Grant plugdev -- `dev` is
# already a member (see default.nix) -- and tag uaccess as belt-and-braces.
# Matching the whole vendor is deliberate: 0x2207 is only ever a Rockchip
# recovery/loader interface, so this also covers other SoCs and future PIDs.
{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    # The pine64/quartz-bsp fork knows RK3588; the upstream rockchip-linux tool
    # predates it.
    pkgs.rkdeveloptool-pine64
  ];

  services.udev.extraRules = ''
    # Pine64 QuartzPro64 (RK3588) maskrom and rkdeveloptool loader.
    SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';
}
