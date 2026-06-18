let
  lan-prefix = "2401:dc20:262f:1:";
  aluminium-vm-prefix = "2401:dc20:262f:20:";
in
{
  aluminium = {
    ipv6 = lan-prefix + "e654:e8ff:fe7d:6173";
    vmSubnet = "${aluminium-vm-prefix}:/60";
  };
  platinum.ipv6 = lan-prefix + "aab8:e0ff:fe06:ae27";
  redbox.ipv6 = lan-prefix + "0::1";
  strontium.ipv6 = "2a0c:9a40:2510:1001::10eb";
  git = {
    ipv6 = aluminium-vm-prefix + "0::10";
    mac = "02:00:00:00:00:01";
  };
  feed = {
    ipv6 = aluminium-vm-prefix + "0::11";
    mac = "02:00:00:00:00:02";
  };
  dev = {
    ipv6 = aluminium-vm-prefix + "0::12";
    mac = "02:00:00:00:00:03";
  };
}
