# NixOS VM test for the mail-relay module. A receiver machine acts as the MX
# for tom-fitzhenry.me.uk (with a minimal DNS server), so we can verify the
# relay end-to-end.
#
# Both machines override the test network's eth1 addresses to avoid collisions.
{ pkgs, lib, ... }:
{
  name = "mail-relay";

  nodes = {
    relay =
      { ... }:
      {
        imports = [ ./. ];

        tomf.mail-relay = {
          enable = true;
          hostname = "al.h.tom-fitzhenry.me.uk";
          recipient = "tom@tom-fitzhenry.me.uk";
        };

        environment.systemPackages = [
          pkgs.opensmtpd
          pkgs.dnsutils
        ];

        networking = {
          useDHCP = false;
          interfaces.eth1.ipv4.addresses = lib.mkOverride 0 [
            {
              address = "192.168.1.1";
              prefixLength = 24;
            }
          ];
          # Resolve tom-fitzhenry.me.uk's MX via the receiver's DNS.
          nameservers = [ "192.168.1.2" ];
          firewall.enable = false;
        };
      };

    receiver =
      { pkgs, ... }:
      {
        services.opensmtpd = {
          enable = true;
          serverConfiguration = ''
            listen on 192.168.1.2

            action "local" maildir "/var/lib/recipient-mail"
            match from any for domain tom-fitzhenry.me.uk action "local"
          '';
        };

        users.users.tom = {
          isSystemUser = true;
          group = "tom";
        };

        users.groups.tom = { };

        systemd.tmpfiles.rules = [
          "d /var/lib/recipient-mail 0700 tom tom -"
        ];

        # A minimal DNS server answering MX tom-fitzhenry.me.uk ->
        # mail.tom-fitzhenry.me.uk -> 192.168.1.2, so the relay has a real
        # destination to deliver to.
        systemd.services.test-dns = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart =
              "${pkgs.dnsmasq}/bin/dnsmasq -k "
              + "--no-resolv "
              + "--mx-host=tom-fitzhenry.me.uk,mail.tom-fitzhenry.me.uk,10 "
              + "--address=/mail.tom-fitzhenry.me.uk/192.168.1.2";
          };
        };

        networking = {
          useDHCP = false;
          interfaces.eth1.ipv4.addresses = lib.mkOverride 0 [
            {
              address = "192.168.1.2";
              prefixLength = 24;
            }
          ];
          firewall.enable = false;
        };

        environment.systemPackages = [ pkgs.opensmtpd ];
      };
  };

  testScript = ''
    relay.wait_for_unit("multi-user.target", timeout=120)
    relay.wait_for_unit("opensmtpd.service", timeout=120)
    receiver.wait_for_unit("multi-user.target", timeout=120)
    receiver.wait_for_unit("opensmtpd.service", timeout=120)
    receiver.wait_for_unit("test-dns.service", timeout=120)
    receiver.wait_until_succeeds("ss -ulnp | grep ':53 '", timeout=30)

    # The relay resolves tom-fitzhenry.me.uk's MX to the receiver.
    mxout = relay.succeed(
      "dig @192.168.1.2 MX tom-fitzhenry.me.uk +time=3 +tries=1", timeout=20)
    assert 'mail.tom-fitzhenry.me.uk' in mxout, mxout

    # External and local addresses are both rewritten to the notification
    # address and delivered.
    relay.succeed(
      "printf 'From: root@al.h.tom-fitzhenry.me.uk\\nTo: someone@example.com\\nSubject: rewritten\\n\\nhi\\n' "
      "| /run/wrappers/bin/sendmail -i -f root@al.h.tom-fitzhenry.me.uk someone@example.com",
      timeout=30,
    )

    relay.succeed(
      "printf 'From: root\\nTo: root\\nSubject: aliased\\n\\nhi\\n' "
      "| /run/wrappers/bin/sendmail -i root",
      timeout=30,
    )

    receiver.wait_until_succeeds(
      "test $(ls /var/lib/recipient-mail/new/ | wc -l) -eq 2",
      timeout=120,
    )
    rewritten = receiver.succeed(
      "grep -rl 'Subject: rewritten' /var/lib/recipient-mail/new/ | xargs cat",
      timeout=30,
    )
    aliased = receiver.succeed(
      "grep -rl 'Subject: aliased' /var/lib/recipient-mail/new/ | xargs cat",
      timeout=30,
    )

    # Both delivered to the notification address (the rewrite applied), with
    # the bare "root" From qualified by the relay domain.
    assert 'From: root@al.h.tom-fitzhenry.me.uk' in aliased, aliased
    assert 'From: root@al.h.tom-fitzhenry.me.uk' in rewritten, rewritten
  '';
}
