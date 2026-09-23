# Allwinner sunxi development (Anbernic H700 handhelds over USB).
#
# The device's boot ROM exposes FEL mode at 1f3a:efe8; libusb-based tools
# (sunxi-fel) need write access to the raw USB node. Once U-Boot runs on the
# same OTG port it re-enumerates as a USB CDC-ACM console gadget, which
# labgrid's USBSerialPort matches (it also appears as /dev/ttyACM*; the
# generic tty rules already grant dialout access, but we pin a stable path).
#
# `dev` is already in plugdev and dialout (see default.nix).
{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.sunxi-tools
  ];

  services.udev.extraRules = ''
    # Allwinner FEL mode (BootROM USB recovery), e.g. Anbernic H700 with no SD.
    SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", MODE="0660", GROUP="plugdev", SYMLINK+="sunxi-fel"

    # U-Boot sunxi USB CDC-ACM console gadget. U-Boot's ARCH_SUNXI defaults are
    # CONFIG_USB_GADGET_VENDOR_NUM=0x1f3a / PRODUCT_NUM=0x1010.
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", MODE="0660", GROUP="dialout", SYMLINK+="h700-console"
  '';
}
