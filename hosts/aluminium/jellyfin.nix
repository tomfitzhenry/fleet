# jellyfin as a native service, LAN-only. Replaces the podman + pomerium setup.
{
  pkgs,
  ...
}:
{
  services.jellyfin = {
    enable = true;
    openFirewall = false; # LAN-only, see firewall rules below.
    hardwareAcceleration = {
      enable = true;
      device = "/dev/dri/renderD128";
      type = "vaapi";
    };
    transcoding = {
      enableHardwareEncoding = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        mpeg2 = true;
        vp9 = true;
      };
    };
  };

  # jellyfin: LAN-only, mirroring the pomerium source_ip policy it replaces.
  networking.firewall.extraInputRules = ''
    ip6 saddr 2401:dc20:262f:1::/64 tcp dport 8096 accept
    ip6 saddr 2401:dc20:262f:1::/64 udp dport 7359 accept # jellyfin auto-discovery
    ip saddr 172.17.1.0/24 tcp dport 8096 accept
    ip saddr 172.17.1.0/24 udp dport 7359 accept # jellyfin auto-discovery
  '';

  # VA-API hardware acceleration for jellyfin transcoding.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  users.users.jellyfin.extraGroups = [
    "render" # VA-API hw acceleration
    "video"
  ];

  # Wait for the NFS automount before jellyfin scans media on /mnt/share.
  systemd.services.jellyfin.after = [ "mnt-share.automount" ];
  systemd.services.jellyfin.wants = [ "mnt-share.automount" ];
}
