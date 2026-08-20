# Trust certificates issued by the fleet's step-ca (see default.nix).
#
# The root certificate is generated on the CA host at first boot, so export it
# here once so it can be baked into the system trust store at build time:
#
#   curl -k https://ca.tom-fitzhenry.me.uk/roots.pem -o modules/step-ca/root_ca.crt
#
# Until the certificate has been exported, this module is a no-op.
{ config, lib, ... }:
{
  options = {
    tomf.step-ca.client = {
      enable = lib.mkEnableOption "trusting the fleet's step-ca";
    };
  };

  config = lib.mkIf config.tomf.step-ca.client.enable {
    security.pki.certificateFiles = lib.mkIf (builtins.pathExists ./root_ca.crt) [
      ./root_ca.crt
    ];
  };
}
