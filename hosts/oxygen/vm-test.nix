# NixOS VM test for oxygen.
{ ... }:
{
  name = "oxygen";
  enableOCR = true;

  nodes.machine =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        ./default.nix
        ../../modules/common
        ../../modules/podman
        ../../modules/remote-builders
        ../../modules/rootfs
        ../../modules/sshd
        ../../modules/tlshd
      ];

      # Disable rootfs module, since the VM test provides it.
      tomf.rootfs.enable = false;

      # Automatically start Sway.
      services.getty.autologinUser = "tom";
      programs.bash.loginShellInit = ''
        if [ "$(tty)" = "/dev/tty1" ]; then
          set -e
          sway
        fi
      '';

      environment.systemPackages = [
        pkgs.firefox
      ];

      virtualisation = {
        qemu.options = [ "-vga none -device virtio-gpu-pci" ];
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Wait for Sway to start
    machine.wait_for_file("/run/user/1000/wayland-1")
    machine.wait_until_succeeds("pgrep -x sway")
    machine.sleep(5)

    # Start Firefox
    machine.succeed("su - tom -c 'firefox about:blank >/tmp/firefox.log 2>&1 &'")
    machine.wait_until_succeeds("pgrep -f firefox")
    machine.wait_for_text("New Tab")
  '';
}
