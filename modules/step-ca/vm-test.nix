# NixOS VM test for the step-ca module.
{ ... }:
{
  name = "step-ca";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ./. ];

      tomf.step-ca = {
        enable = true;
        # Bind IPv6 (as in production) and map the CA name to IPv6 loopback.
        address = "[::]";
      };

      networking.hosts."::1" = [ "ca.tom-fitzhenry.me.uk" ];

      environment.systemPackages = with pkgs; [
        curl
        jq
        step-cli
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("step-ca.service")

    # Root and intermediate CAs are generated on first boot.
    machine.succeed("step certificate inspect /var/lib/step-ca/root_ca.crt --format json | jq -e '.extensions.basic_constraints.is_ca == true'")
    machine.succeed("step certificate inspect /var/lib/step-ca/intermediate_ca.crt --format json | jq -e '.extensions.name_constraints.permitted_names == [\"tom-fitzhenry.me.uk\"]'")
    machine.succeed("step certificate verify /var/lib/step-ca/intermediate_ca.crt --roots /var/lib/step-ca/root_ca.crt")

    # step-ca serves the root and the ACME directory on its own TLS.
    root_crt = machine.succeed("cat /var/lib/step-ca/root_ca.crt")
    served = machine.succeed("curl -sk https://ca.tom-fitzhenry.me.uk/roots.pem")
    assert root_crt == served, "step-ca should serve the root at /roots.pem"
    machine.succeed("curl -sk https://ca.tom-fitzhenry.me.uk/acme/acme/directory | jq -e '.newNonce != null'")

    # End-to-end: bootstrap trust and issue a certificate via the ACME
    # provisioner. step-cli serves the HTTP-01 challenge itself (--standalone);
    # step-ca validates it over loopback.
    fingerprint = machine.succeed("step certificate fingerprint /var/lib/step-ca/root_ca.crt").strip()
    machine.succeed(f"step ca bootstrap --ca-url https://ca.tom-fitzhenry.me.uk --fingerprint {fingerprint}")
    machine.succeed(
      "step ca certificate ca.tom-fitzhenry.me.uk /tmp/cert.crt /tmp/cert.key "
      "--acme https://ca.tom-fitzhenry.me.uk/acme/acme/directory "
      "--root /var/lib/step-ca/root_ca.crt --standalone"
    )
    machine.succeed("step certificate verify /tmp/cert.crt --roots /var/lib/step-ca/root_ca.crt")
    machine.succeed("step certificate inspect /tmp/cert.crt --format json | jq -e '.subject.common_name[0] == \"ca.tom-fitzhenry.me.uk\"'")
  '';
}
