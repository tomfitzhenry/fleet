# NixOS VM test for the spire module. Two nodes: a central `server` that owns
# the fleet map and runs spire-controller-manager in Static Mode, and an
# `agent` that proves node identity with a software TPM (swtpm) and hands
# SVIDs to explicitly enrolled systemd services.
#
# The swtpm EK must be known at eval time so it can be pinned on the server. We
# generate a fixed TPM state here (go-attestation reads a kernel TPM device, not
# a unix socket, so the hash is computed with tpm2-tools + openssl), then boot
# the agent against a writable copy of that state via NIX_SWTPM_DIR. Because the
# state is fixed, the guest derives exactly the same EK (and hash).
{ pkgs, lib, ... }:
let
  trustDomain = "example.org";

  entriesUnit = "spire-controller-manager.service";

  spireTpmEk =
    pkgs.runCommand "spire-tpm-ek"
      {
        nativeBuildInputs = [
          pkgs.swtpm
          pkgs.tpm2-tools
          pkgs.openssl
        ];
      }
      ''
        set -euo pipefail
        state="$TMPDIR/state"
        mkdir -p "$state"
        swtpm socket \
          --tpmstate dir="$state" \
          --server type=unixio,path="$state/socket" \
          --ctrl type=unixio,path="$state/socket.ctrl" \
          --pid file="$state/pid" --daemon \
          --flags not-need-init --tpm2 \
          --log file="$state/log",level=6
        for _ in $(seq 1 100); do [ -S "$state/socket" ] && break; sleep 0.1; done

        export TPM2TOOLS_TCTI=swtpm:path="$state/socket"
        tpm2_startup --clear
        tpm2_startup
        tpm2_createek -G rsa -u "$TMPDIR/ek.pem" -c "$TMPDIR/ek.ctx" -f pem
        tpm2_shutdown
        tpm2_shutdown --clear

        swtpm_ioctl --unix "$state/socket.ctrl" --stop || true
        pid="$(cat "$state/pid")"
        for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done

        mkdir -p "$out/state"
        cp "$state/tpm2-00.permall" "$out/state/tpm2-00.permall"
        chmod 0444 "$out/state/tpm2-00.permall"

        openssl pkey -pubin -in "$TMPDIR/ek.pem" -outform DER \
          | sha256sum | cut -d' ' -f1 > "$out/ekHash"
      '';

  ekHash = lib.removeSuffix "\n" (builtins.readFile "${spireTpmEk}/ekHash");

  # Capture a server CA and its trust bundle at build time, so the agent can be
  # seeded with a static bundle (no runtime bootstrap service). The server's
  # datastore (which holds the CA journal) and disk KeyManager keys are copied
  # into the test server's state dir; the captured PEM then matches that CA.
  # ca_ttl is set to the module default so this also checks SPIRE accepts it.
  spireBundle =
    pkgs.runCommand "spire-test-bundle"
      {
        nativeBuildInputs = [ pkgs.spire ];
      }
      ''
        set -euo pipefail
        data="$TMPDIR/data"
        mkdir -p "$data"
        cat > "$TMPDIR/server.conf" <<EOF
        server {
          trust_domain = "${trustDomain}"
          data_dir = "$data"
          bind_address = "127.0.0.1"
          bind_port = "0"
          socket_path = "$data/api.sock"
          ca_ttl = "87600h"
          log_level = "ERROR"
        }
        plugins {
          DataStore "sql" {
            plugin_data {
              database_type = "sqlite3"
              connection_string = "$data/datastore.sqlite3"
            }
          }
          KeyManager "disk" {
            plugin_data { keys_path = "$data/keys.json" }
          }
          NodeAttestor "join_token" { plugin_data {} }
        }
        EOF
        spire-server run -config "$TMPDIR/server.conf" &
        pid=$!
        for _ in $(seq 1 150); do [ -S "$data/api.sock" ] && break; sleep 0.2; done
        spire-server healthcheck -socketPath "$data/api.sock"
        mkdir -p "$out"
        spire-server bundle show -socketPath "$data/api.sock" -format pem > "$out/bundle.pem"
        # Stop the server first so SQLite checkpoints its WAL into the main DB
        # file; a snapshot of a live datastore would be missing the CA record.
        kill "$pid" || true
        wait "$pid" || true
        cp "$data/keys.json" "$out/keys.json"
        cp "$data/datastore.sqlite3" "$out/datastore.sqlite3"
      '';

  agentSocket = "/run/spire/agent/public/api.sock";
  ghostunnel = "${pkgs.ghostunnel}/bin/ghostunnel";
  socat = "${pkgs.socat}/bin/socat";

  echoPort = 8080;
  serverPort = 8443;
  clientPort = 8444;

  serverSpiffeId = "spiffe://${trustDomain}/agent/mtls-server";
  clientSpiffeId = "spiffe://${trustDomain}/agent/mtls-client";
in
{
  name = "spire";

  nodes.server =
    { pkgs, lib, ... }:
    {
      imports = [ ./. ];

      tomf.spire = {
        enable = true;
        trustDomain = trustDomain;
        server = {
          enable = true;
          bindAddress = "0.0.0.0";
          bindPort = 8081;
          openFirewall = true;
          nodes.agent = {
            ekHash = ekHash;
            users = [ "workload" ];
            system-units = [
              "hello"
              "mtls-server"
              "mtls-client"
            ];
          };
        };
      };

      # Seed the server's state dir with the build-time CA (datastore + keys) so
      # the agent's trust bundle matches. -m 0600: the Nix store copies are
      # read-only and SQLite must be able to write. Runs as the DynamicUser.
      systemd.services.spire-server.serviceConfig.ExecStartPre = lib.mkBefore [
        "${pkgs.coreutils}/bin/install -m 0600 ${spireBundle}/keys.json /var/lib/spire/server/keys.json"
        "${pkgs.coreutils}/bin/install -m 0600 ${spireBundle}/datastore.sqlite3 /var/lib/spire/server/datastore.sqlite3"
      ];
    };

  nodes.agent =
    { pkgs, lib, ... }:
    {
      imports = [ ./. ];

      virtualisation.tpm.enable = true;

      tomf.spire = {
        enable = true;
        trustDomain = trustDomain;
        # Override the module's default fleet CA with the throwaway test CA.
        trustBundleFile = "${spireBundle}/bundle.pem";
        agent = {
          enable = true;
          serverAddress = "server";
          serverPort = 8081;
        };
      };

      users.users.workload = {
        isNormalUser = true;
        group = "workload";
      };
      users.groups.workload = { };

      # Runs inside its own cgroup so the systemd workload attestor can map it
      # to systemd:id:hello.service.
      systemd.services.hello = {
        after = [ "spire-agent.service" ];
        requires = [ "spire-agent.service" ];
        startLimitIntervalSec = 0;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${lib.getExe' pkgs.spire "spire-agent"} api fetch x509 \
            -socketPath /run/spire/agent/public/api.sock > /run/hello-svid.txt
        '';
      };

      # A plain echo backend that the mTLS server proxies to. cat is a
      # bidirectional echo over the socket socat gives it.
      systemd.services.mtls-backend = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${socat} TCP-LISTEN:${toString echoPort},bind=127.0.0.1,reuseaddr,fork EXEC:cat";
        };
      };

      # ghostunnel terminates mTLS for a workload that gets its X.509-SVID
      # from the Workload API, then forwards plaintext to the echo backend.
      # --allow-uri is checked against the peer's SPIFFE ID (the URI SAN of the
      # verified SVID), so only the mtls-client workload is accepted.
      systemd.services.mtls-server = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "spire-agent.service"
          "mtls-backend.service"
        ];
        requires = [
          "spire-agent.service"
          "mtls-backend.service"
        ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          ExecStart = ''
            ${ghostunnel} server \
              --use-workload-api-addr unix://${agentSocket} \
              --listen 127.0.0.1:${toString serverPort} \
              --target 127.0.0.1:${toString echoPort} \
              --allow-uri ${clientSpiffeId}
          '';
        };
      };

      # ghostunnel client gets its own SVID from the Workload API, requires the
      # server's SPIFFE ID (--verify-uri), and wraps plaintext arriving on
      # 127.0.0.1:clientPort in mTLS toward the server. Separate unit => its own
      # cgroup => a distinct SVID from mtls-server.
      systemd.services.mtls-client = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "spire-agent.service"
          "mtls-server.service"
        ];
        requires = [
          "spire-agent.service"
          "mtls-server.service"
        ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          ExecStart = ''
            ${ghostunnel} client \
              --use-workload-api-addr unix://${agentSocket} \
              --listen 127.0.0.1:${toString clientPort} \
              --target 127.0.0.1:${toString serverPort} \
              --verify-uri ${serverSpiffeId}
          '';
        };
      };
    };

  testScript = ''
    import os
    import shutil
    import tempfile

    # Point swtpm at a writable copy of the fixed state (NIX_SWTPM_DIR is read by
    # the pinned qemu-vm launch script). This must happen before the agent VM
    # starts; machines start lazily on first use.
    swtpm_dir = tempfile.mkdtemp(prefix="spire-swtpm-")
    swtpm_state = os.path.join(swtpm_dir, "tpm2-00.permall")
    shutil.copyfile("${spireTpmEk}/state/tpm2-00.permall", swtpm_state)
    os.chmod(swtpm_state, 0o600)
    os.environ["NIX_SWTPM_DIR"] = swtpm_dir

    show = "spire-server entry show -socketPath /run/spire/server/private/api.sock -output json"

    with subtest("the agent derives the pinned EK hash"):
        guest_ek_hash = agent.succeed("get_tpm_pubhash").strip()
        assert guest_ek_hash == "${ekHash}", (
            f"guest get_tpm_pubhash={guest_ek_hash} != baked ekHash=${ekHash}"
        )

    with subtest("server and agent are healthy"):
        server.wait_for_unit("spire-server.service", timeout=120)
        server.wait_for_unit("${entriesUnit}", timeout=120)
        agent.wait_for_unit("spire-agent.service", timeout=180)
        server.wait_until_succeeds(
            "spire-server healthcheck -socketPath /run/spire/server/private/api.sock",
            timeout=120,
        )
        agent.wait_until_succeeds(
            "spire-agent healthcheck -socketPath /run/spire/agent/public/api.sock",
            timeout=180,
        )

    with subtest("the agent's node alias entry is registered from the pinned hash"):
        import json

        entries = json.loads(server.succeed(show))
        node = [e for e in entries["entries"] if e["parent_id"]["path"] == "/spire/server"]
        assert node, entries
        assert any(
            s["type"] == "tpm" and s["value"] == "pub_hash:${ekHash}"
            for e in node
            for s in e["selectors"]
        ), node
        assert any(
            e["spiffe_id"]["path"] == "/agent" and e["spiffe_id"]["trust_domain"] == "${trustDomain}"
            for e in node
        ), node

    with subtest("the controller is idempotent across a restart"):
        import json

        # node(agent) + hello + workload user + mtls-server + mtls-client.
        before = json.loads(server.succeed(show))["entries"]
        assert len(before) == 5, before

        server.succeed("systemctl restart ${entriesUnit}")
        server.wait_for_unit("${entriesUnit}", timeout=60)
        server.succeed("systemctl is-active ${entriesUnit}")

        after = json.loads(server.succeed(show))["entries"]
        assert len(after) == len(before) == 5, after

    with subtest("systemd service gets its workload SVID"):
        agent.wait_until_succeeds("systemctl start hello.service", timeout=180)
        output = agent.succeed("cat /run/hello-svid.txt")
        assert "spiffe://${trustDomain}/agent/hello" in output, output

    with subtest("a non-root user reaches the Workload API"):
        output = agent.wait_until_succeeds(
            "su -s /bin/sh workload -c "
            "'spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock'",
            timeout=120,
        )
        assert "spiffe://${trustDomain}/agent/user/workload" in output, output

    with subtest("API workloads perform mutual TLS with their SVIDs"):
        agent.wait_for_unit("mtls-server.service", timeout=180)
        agent.wait_for_unit("mtls-client.service", timeout=180)

        # A payload written to the client's plaintext listener is wrapped in
        # mTLS using the client's Workload API SVID, forwarded to the server,
        # which checks the client's SPIFFE ID against --allow-uri, proxies it to
        # the echo backend, and returns it. A successful round-trip therefore
        # proves both SVIDs were presented and accepted: the server only permits
        # ${clientSpiffeId}, and the client only verifies ${serverSpiffeId}.
        # Hold stdin open briefly: ghostunnel tears the whole tunnel down on a
        # half-close, so closing stdin before the reply returns loses the echo.
        agent.wait_until_succeeds(
            "(printf 'ping\\n'; sleep 2) | "
            "${socat} -t 3 - TCP:127.0.0.1:${toString clientPort} | grep -q '^ping$'",
            timeout=180,
        )

        # Negative control: the server must reject a workload whose SVID is not
        # the allowed mtls-client ID. Run a second ghostunnel client as the
        # `workload` user (SVID .../agent/user/workload) against the same server.
        agent.succeed(
            "systemd-run --unit=mtls-intruder --uid=workload "
            "--setenv=SPIFFE_ENDPOINT_SOCKET=unix://${agentSocket} "
            "${ghostunnel} client "
            "--listen 127.0.0.1:8555 --target 127.0.0.1:${toString serverPort} "
            "--verify-uri ${serverSpiffeId}"
        )
        agent.wait_for_unit("mtls-intruder.service", timeout=60)
        agent.wait_for_open_port(8555, timeout=60)
        # TCP is accepted, but the mTLS handshake fails because the server
        # disallows the workload-user SPIFFE ID, so nothing comes back.
        agent.fail(
            "printf 'ping\\n' | ${socat} -t 3 - TCP:127.0.0.1:8555 "
            "| grep -q '^ping$'"
        )
        agent.succeed("systemctl stop mtls-intruder.service")

    with subtest("the controller self-heals a deleted node entry"):
        import json
        import time

        entries = json.loads(server.succeed(show))["entries"]
        node = [e for e in entries if e["parent_id"]["path"] == "/spire/server"][0]
        server.succeed(
            "spire-server entry delete -socketPath /run/spire/server/private/api.sock "
            f"-entryID {node['id']}"
        )

        # Static mode reconciles on its GC interval; wait for the entry to
        # reappear without bouncing the service.
        for _ in range(60):
            current = json.loads(server.succeed(show))["entries"]
            if any(e["parent_id"]["path"] == "/spire/server" for e in current):
                break
            time.sleep(1)
        after = json.loads(server.succeed(show))["entries"]
        assert len(after) == 5, after
        assert any(e["parent_id"]["path"] == "/spire/server" for e in after), after

    with subtest("the controller shuts down cleanly"):
        server.succeed("systemctl stop ${entriesUnit}")
        status = server.succeed(
            "systemctl show -p ExecMainStatus --value ${entriesUnit}"
        ).strip()
        assert status == "0", f"ExecMainStatus={status}"
        logs = server.succeed(
            "journalctl -u ${entriesUnit} --no-pager -b"
        )
        assert "panic:" not in logs, logs[-2000:]
  '';
}
