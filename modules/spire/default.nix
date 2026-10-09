# A module that runs a SPIRE server and/or agent. A single central server owns
# the fleet map (node identity via TPM EK hash -> host alias, and which users
# and units get SVIDs); agents are minimal and just connect to that server.
#
# Registrations are applied by spire-controller-manager in its non-Kubernetes
# "Static Mode": Nix generates ClusterStaticEntry manifests from
# `server.nodes` and the controller reconciles them onto the local server over
# its admin socket. There is no hand-rolled `spire-server entry create` batch.
#
# See https://spiffe.io/, https://github.com/spiffe/spire-tpm-plugin and
# https://github.com/spiffe/spire-controller-manager.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tomf.spire;

  # Standard paths. The nixpkgs SPIRE modules already default to these sockets.
  serverSocket = "/run/spire/server/private/api.sock";
  agentSocket = "/run/spire/agent/public/api.sock";

  serverId = "spiffe://${cfg.trustDomain}/spire/server";
  nodeId = name: "spiffe://${cfg.trustDomain}/${name}";

  # Commit the fleet server's CA at this path and every host picks it up. A
  # missing file is not an error: agents then require an explicit
  # `trustBundle`/`trustBundleFile` (and warn).
  defaultTrustBundleFile = ./trust-bundle.pem;

  # The X.509 trust bundle handed to the agent as a file. The bundle is public
  # trust material; nothing is fetched at runtime. Explicit options win: a
  # pre-built `trustBundleFile` beats embedded `trustBundle` contents (which
  # would need an eval-time import-from-derivation), and both beat the default.
  trustBundlePath =
    if cfg.trustBundleFile != null then
      "${cfg.trustBundleFile}"
    else if cfg.trustBundle != null then
      "${pkgs.writeText "spire-trust-bundle.pem" cfg.trustBundle}"
    else if builtins.pathExists defaultTrustBundleFile then
      "${defaultTrustBundleFile}"
    else
      null;

  # --- server-side fleet map --------------------------------------------
  serverNodes = cfg.server.nodes;

  # The tpm NodeAttestor allow-lists every node's EK public key hash: a
  # directory with one empty file per allowed hash. Pinning the hashes in Nix
  # lets this be a store path, so no runtime hashing service is needed.
  pinnedHashDir = pkgs.runCommand "spire-tpm-hashes" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (h: ": > $out/${h}") (
      lib.mapAttrsToList (_: n: n.ekHash) serverNodes
    )}
  '';
  hashPath = "${pinnedHashDir}";

  # metadata.name only needs to be a valid DNS subdomain; the entry identity is
  # spiffeID/parentID/selectors.
  sanitizeName =
    s: lib.toLower (builtins.replaceStrings [ "_" "." ":" "/" " " ] (lib.genList (_: "-") 5) s);

  clusterStaticEntry = name: spec: {
    apiVersion = "spire.spiffe.io/v1alpha1";
    kind = "ClusterStaticEntry";
    metadata.name = name;
    inherit spec;
  };

  # A node alias is expressible as a ClusterStaticEntry whose parent is the
  # SPIRE server and whose selector is a node selector.
  nodeStaticEntry =
    name: node:
    clusterStaticEntry "node-${sanitizeName name}" {
      spiffeID = nodeId name;
      parentID = serverId;
      selectors = [ "tpm:pub_hash:${node.ekHash}" ];
    };

  # Convenience enrollments for a node. Keys are namespaced -- system units by
  # their bare name, users as `user-<name>` -- so the two sets cannot collide;
  # an explicit `workloads.<key>` overrides the generated entry of that key.
  nodeWorkloads =
    name: node:
    (lib.listToAttrs (
      map (unit: {
        name = unit;
        value = {
          spiffeId = "${nodeId name}/${unit}";
          selectors = [ "systemd:id:${unit}.service" ];
        };
      }) node.system-units
    ))
    // (lib.listToAttrs (
      map (user: {
        name = "user-${user}";
        value = {
          spiffeId = "${nodeId name}/user/${user}";
          selectors = [ "unix:user:${user}" ];
        };
      }) node.users
    ))
    // node.workloads;

  workloadStaticEntry =
    nodeName: key: w:
    clusterStaticEntry "workload-${sanitizeName nodeName}-${sanitizeName key}" {
      spiffeID = if w.spiffeId != null then w.spiffeId else "${nodeId nodeName}/${key}";
      parentID = nodeId nodeName;
      selectors = w.selectors;
    };

  staticEntries = lib.concatLists (
    lib.mapAttrsToList (
      name: node:
      [ (nodeStaticEntry name node) ]
      ++ lib.mapAttrsToList (workloadStaticEntry name) (nodeWorkloads name node)
    ) serverNodes
  );

  yamlFormat = pkgs.formats.yaml { };

  staticManifestDir = pkgs.linkFarm "spire-static-manifests" (
    map (e: {
      name = "${e.metadata.name}.yaml";
      path = yamlFormat.generate "${e.metadata.name}.yaml" e;
    }) staticEntries
  );

  # NB: `gcInterval` is a numeric time.Duration upstream, not the "10s" string
  # the docs show, so leave it unset and take the 10s default.
  controllerManagerConfig = yamlFormat.generate "spire-controller-manager.yaml" {
    apiVersion = "spire.spiffe.io/v1alpha1";
    kind = "ControllerManagerConfig";
    clusterName = config.networking.hostName;
    trustDomain = cfg.trustDomain;
    clusterDomain = "cluster.local";
    staticManifestPath = "${staticManifestDir}";
    spireServerSocketPath = serverSocket;
    logLevel = "info";
    metrics.bindAddress = "0";
    health.healthProbeBindAddress = "0";
  };

  # The server's admin socket is created in a 0750 directory and is itself
  # 0770, both owned by the server's DynamicUser. Instead of running the
  # reconciler as root, give the socket directory a dedicated group (setgid so
  # the recreated socket inherits it) that both the server and the controller
  # are members of. This keeps the server a DynamicUser and leaves the socket
  # inaccessible to "other"; the public agent socket is untouched.
  socketGroup = "spire-controller";
  socketDirSetup = pkgs.writeShellScript "spire-server-socket-dir" ''
    ${pkgs.coreutils}/bin/install -d -m 2770 -o root -g ${socketGroup} /run/spire/server/private
  '';

  spireControllerManager = pkgs.callPackage ../../pkgs/spire-controller-manager { };

  # A colocated agent talks to the server at its bind address; on any other
  # host `serverAddress` must be set (asserted below).
  effectiveServerAddress =
    if cfg.agent.serverAddress != null then
      cfg.agent.serverAddress
    else if cfg.server.enable then
      cfg.server.bindAddress
    else
      "127.0.0.1";

  # A placeholder for an EK hash that could not be read from the build host.
  # Nodes still using it cannot attest; the warning below tells the operator to
  # fill in the real value from `get_tpm_pubhash`.
  placeholderEkHash = lib.concatStrings (lib.genList (_: "0") 64);
in
{
  options.tomf.spire = {
    enable = lib.mkEnableOption "SPIRE (server and/or agent)";

    trustDomain = lib.mkOption {
      type = lib.types.str;
      default = "fleet";
      description = "SPIFFE trust domain.";
    };

    trustBundle = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        PEM-encoded server trust bundle, as printed by
        `spire-server bundle show -socketPath /run/spire/server/private/api.sock -format pem`.

        This is public trust material. When set it overrides the module's
        default bundle and is written to a store file handed to the agent via
        `trust_bundle_path`.
      '';
    };

    trustBundleFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a PEM-encoded server trust bundle, as an alternative to
        `trustBundle`. Use this when the bundle is produced by another
        derivation; it avoids an eval-time import-from-derivation. Takes
        precedence over both `trustBundle` and the module's default bundle.
      '';
    };

    server = {
      enable = lib.mkEnableOption "the SPIRE server";

      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address the server's agent-facing gRPC endpoint binds to. Set to a
          fleet-reachable address (e.g. the WireGuard IP) for remote agents.
        '';
      };

      bindPort = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Port the server's agent-facing gRPC endpoint binds to.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the firewall for `bindPort`.";
      };

      caTTL = lib.mkOption {
        type = lib.types.str;
        default = "87600h";
        description = ''
          Lifetime of the server CA / trust bundle, as a Go duration string
          (`87600h` is 10 years). Only takes effect on a fresh server state;
          an existing CA is reused until it expires.
        '';
      };

      nodes = lib.mkOption {
        default = { };
        description = ''
          The fleet map, one attribute per agent host, keyed by the host's
          alias under the trust domain. The server publishes a TPM node-alias
          entry and any enrollments for each node.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              ekHash = lib.mkOption {
                type = lib.types.strMatching "[0-9a-f]{64}";
                description = ''
                  SHA-256 of the node's TPM EK public key, from
                  `get_tpm_pubhash` on that node.
                '';
              };
              system-units = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Systemd units (without the `.service` suffix) to grant an
                  SVID to. Each `"foo"` registers
                  `spiffe://<trustDomain>/<node>/foo` with selector
                  `systemd:id:foo.service`.
                '';
              };
              users = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Local users to grant an SVID to. Each `"tom"` registers
                  `spiffe://<trustDomain>/<node>/user/tom` with selector
                  `unix:user:tom`.
                '';
              };
              workloads = lib.mkOption {
                default = { };
                description = ''
                  Advanced escape hatch for custom SPIFFE IDs and selectors.
                  An explicit entry overrides a same-keyed generated entry
                  (system units use their bare name; users use `user-<name>`).
                '';
                type = lib.types.attrsOf (
                  lib.types.submodule (
                    { name, ... }:
                    {
                      options = {
                        spiffeId = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = ''
                            Full SPIFFE ID. Defaults to
                            `spiffe://<trustDomain>/<node>/<name>`.
                          '';
                        };
                        selectors = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ "systemd:id:${name}.service" ];
                          description = "Selectors that must all match.";
                        };
                      };
                    }
                  )
                );
              };
            };
          }
        );
      };
    };

    agent = {
      enable = lib.mkEnableOption "the SPIRE agent";

      serverAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Address (IP or hostname) of the central SPIRE server. Defaults to the
          server's `bindAddress` when this host also runs the server.
        '';
      };

      serverPort = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Port of the central SPIRE server's agent-facing endpoint.";
      };

      rebootstrapMode = lib.mkOption {
        type = lib.types.enum [
          "never"
          "auto"
        ];
        default = "auto";
        description = ''
          SPIRE's `rebootstrap_mode`. With `"auto"` the agent re-runs node
          attestation when the server presents an unknown X.509 certificate,
          self-healing a stale cached trust bundle
          (`/var/lib/spire/agent/agent-data.json`) after a CA rotation. SPIRE
          also accepts `"always"`, which is not exposed here.
        '';
      };

      rebootstrapDelay = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          SPIRE's `rebootstrap_delay`, a Go duration string (e.g. `"1h"`). How
          long to wait after seeing an unknown server certificate before
          rebootstrapping. When null SPIRE's own default (`10m`) applies.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.agent.enable || cfg.agent.serverAddress != null || cfg.server.enable;
        message = "tomf.spire.agent.serverAddress must be set when this host does not run its own SPIRE server.";
      }
      {
        assertion = lib.all (n: !(builtins.any (u: builtins.elem "user-${u}" n.system-units) n.users)) (
          lib.attrValues cfg.server.nodes
        );
        message = "tomf.spire.server.nodes.<node>: a system unit named 'user-<x>' collides with the generated key for a users entry; rename the unit or use workloads.";
      }
    ];

    # Non-fatal: an agent without a trust bundle cannot authenticate the
    # server, but the rest of the host still evaluates/builds.
    warnings =
      lib.optional (cfg.agent.enable && trustBundlePath == null) ''
        tomf.spire: no agent trust bundle is configured, so the agent cannot authenticate the server.
        Once the central server has run, obtain its CA bundle with:
          spire-server bundle show -socketPath /run/spire/server/private/api.sock -format pem
        and commit it as modules/spire/trust-bundle.pem (or set tomf.spire.trustBundle /
        tomf.spire.trustBundleFile to it).
      ''
      ++
        lib.optional (builtins.any (n: n.ekHash == placeholderEkHash) (lib.attrValues cfg.server.nodes))
          "tomf.spire.server.nodes: one or more `ekHash` values are the all-zero placeholder. Run `get_tpm_pubhash` on that host and replace it with the real 64-hex value; until then that node cannot attest.";

    # A shared group for the server's private socket directory, so the
    # controller-manager can reach the admin socket without running as root.
    users.groups = lib.mkIf cfg.server.enable {
      ${socketGroup} = { };
    };

    # The tss group and /dev/tpmrm0 node must exist for the TPM plugins.
    security.tpm2.enable = true;

    services.spire.server = lib.mkIf cfg.server.enable {
      enable = true;
      openFirewall = cfg.server.openFirewall;
      settings = {
        server = {
          trust_domain = cfg.trustDomain;
          socket_path = serverSocket;
          bind_address = cfg.server.bindAddress;
          bind_port = cfg.server.bindPort;
          ca_ttl = cfg.server.caTTL;
        };
        plugins = {
          DataStore.sql.plugin_data = {
            database_type = "sqlite3";
            connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
          };
          # A persistent disk CA, so SVIDs survive restarts. Unlike the agent,
          # the server's disk KeyManager stores a single keys file.
          KeyManager.disk.plugin_data = {
            keys_path = "$STATE_DIRECTORY/keys.json";
          };
          NodeAttestor.tpm.plugin_data.hash_path = hashPath;
        };
      };
    };

    services.spire.agent = lib.mkIf cfg.agent.enable {
      enable = true;
      settings = {
        agent = {
          trust_domain = cfg.trustDomain;
          server_address = effectiveServerAddress;
          server_port = cfg.agent.serverPort;
          # Self-heal a stale cached trust bundle after a CA rotation: on
          # seeing an unknown server certificate the agent re-runs node
          # attestation rather than trusting /var/lib/spire/agent/agent-data.json
          # forever.
          rebootstrap_mode = cfg.agent.rebootstrapMode;
          trust_bundle_format = "pem";
          socket_path = agentSocket;
        }
        // lib.optionalAttrs (trustBundlePath != null) {
          trust_bundle_path = trustBundlePath;
        }
        // lib.optionalAttrs (cfg.agent.rebootstrapDelay != null) {
          rebootstrap_delay = cfg.agent.rebootstrapDelay;
        };
        plugins = {
          KeyManager.disk.plugin_data = {
            directory = "$STATE_DIRECTORY";
          };
          NodeAttestor.tpm.plugin_data = { };
          WorkloadAttestor.systemd.plugin_data = { };
          WorkloadAttestor.unix.plugin_data = { };
        };
      };
    };

    systemd.services = lib.mkMerge [
      # The agent talks to /dev/tpmrm0 directly, so wait for the TPM device.
      (lib.mkIf cfg.agent.enable {
        spire-agent = {
          wants = [ "tpm2.target" ];
          after = [ "tpm2.target" ];
        };
      })

      # Give the server's private socket directory a group shared with the
      # controller, and make the socket inherit it via the setgid bit. The
      # directory is removed and recreated by systemd on every server start,
      # hence the root ExecStartPre.
      (lib.mkIf cfg.server.enable {
        spire-server.serviceConfig = {
          SupplementaryGroups = [ socketGroup ];
          ExecStartPre = lib.mkAfter [ "+${socketDirSetup}" ];
        };
      })

      # Reconcile the generated ClusterStaticEntry manifests onto the server.
      (lib.mkIf cfg.server.enable {
        spire-controller-manager = {
          description = "SPIRE Controller Manager (static mode)";
          wantedBy = [ "multi-user.target" ];
          after = [ "spire-server.service" ];
          requires = [ "spire-server.service" ];
          partOf = [ "spire-server.service" ];
          serviceConfig = {
            ExecStart = "${lib.getExe spireControllerManager} -config ${controllerManagerConfig}";
            Restart = "on-failure";
            RestartSec = 2;
            DynamicUser = true;
            SupplementaryGroups = [ socketGroup ];
          };
        };
      })

      # A colocated agent can only attest once the node alias entry exists,
      # which the controller creates asynchronously; the agent retries.
      (lib.mkIf (cfg.agent.enable && cfg.server.enable) {
        spire-agent.after = [ "spire-controller-manager.service" ];
      })
    ];

    # Let tools and units find the Workload API without a flag. go-spiffe
    # requires the SPIFFE_ENDPOINT_SOCKET value to be a URI, so use unix://.
    systemd.globalEnvironment.SPIFFE_ENDPOINT_SOCKET = lib.mkIf cfg.agent.enable "unix://${agentSocket}";

    environment.systemPackages = [ pkgs.spire-tpm-plugin ];
  };
}
