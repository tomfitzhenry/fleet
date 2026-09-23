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

  # for live USB packet capture (usbmon), also:
  boot.kernelModules = [ "usbmon" ];

  services.udev.extraRules = ''
    # U-Boot fastboot gadget shares VID:PID with the console but is a
    # vendor-specific interface (0xff/0x42/0x03), not a tty; libusb needs
    # raw USB access, so grant it like FEL.
    SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="1010", MODE="0660", GROUP="plugdev"
    # Linux legacy g_serial CDC-ACM console (NetChip 0525:a4a7).
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0525", ATTRS{idProduct}=="a4a7", MODE="0660", GROUP="dialout", SYMLINK+="h700-linux-console"

    SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", MODE="0660", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0525", MODE="0660", GROUP="plugdev"

    # Allwinner FEL mode (BootROM USB recovery), e.g. Anbernic H700 with no SD.
    SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", MODE="0660", GROUP="plugdev", SYMLINK+="sunxi-fel"

    # U-Boot sunxi USB CDC-ACM console gadget. U-Boot's ARCH_SUNXI defaults are
    # CONFIG_USB_GADGET_VENDOR_NUM=0x1f3a / PRODUCT_NUM=0x1010.
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", MODE="0660", GROUP="dialout", SYMLINK+="h700-console"

    # U-Boot fastboot gadget shares VID:PID with the console but is a
    # vendor-specific interface (0xff/0x42/0x03), not a tty; libusb needs
    # raw USB access, so grant it like FEL.
    SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="1010", MODE="0660", GROUP="plugdev"
    # Linux legacy g_serial CDC-ACM console (NetChip 0525:a4a7).
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0525", ATTRS{idProduct}=="a4a7", MODE="0660", GROUP="dialout", SYMLINK+="h700-linux-console"
  '';
}
