# Architecture Principles

## Availability & Independence

**Any host can be down at any time, potentially for a long time.** There is no guarantee
that all machines are running simultaneously.

- **No cross-machine dependencies at runtime.** A service on host A must not require a
  service on host B to function. If two services communicate, the client must handle the
  server being absent gracefully.

## Networking

### IPv6-first, direct routing

Machines should be directly routable. This practically means IPv6: every host gets its
own globally routable address.

- Prefer IPv6 for all service-to-service communication.
- Keep IPv4 at the network edge. Use **snid** for TLS reverse-proxying of IPv4 services.
- Avoid NAT where possible. Direct routing simplifies the network and removes a class of
  bugs.

### No tunnelling

Avoid tunnels (WireGuard excepted as an auth mechanism of last resort). Tunnels impose
constraints on clients, add operational complexity, and obscure what's happening on the
wire.

- WireGuard is acceptable as an authentication/authorisation layer when mTLS, OIDC, and
  oauth2-proxy won't work. It should be the exception, not the norm.
- No overlay networks, no SD-WAN, no mesh VPNs.

## Process Isolation

### microvm.nix for trust-domain isolation

Linux containers are **not** trusted as a security boundary. Use `microvm.nix` (KVM-based
virtual machines) to isolate services in different trust domains.

- Services in the same trust domain can share a microvm.
- Services in different trust domains get separate microvms.
- The NixOS host is the hypervisor and part of the TCB. Minimise what runs directly on the
  host: the goal is to move services into microvms over time.
- Within a microvm, services still run with least privilege (`DynamicUser`, restricted
  filesystem access).

### virtiofs for persistence

Use `microvm.shares` (virtiofs) for persistent guest directories: not
`microvm.volumes` (block device images). Shares are backed by host directories under
`/var/lib/microvms/`.

## Software Stack

### Memory safety

Anything exposed to untrusted input must be memory-safe. Rust and Go are preferred. Other
memory-safe languages (Java, C#, etc.) are acceptable if the specific service has a strong
security reputation.

Exceptions: Linux kernel (incl. Wireguard), OpenSSH, and services with limited blast radius.

### Simplicity

Prefer simple, focused tools over complex platforms.

- Single-binary deployments over multi-service stacks.
- NixOS modules from nixpkgs over third-party flakes.
- **SQLite over PostgreSQL** for single-machine services.

## Secrets Management

**Preference: eliminate secrets entirely.** Use hardware-backed keys (TPM, YubiKey,
keyring) for authentication where possible, so there's no secret to manage.

When secrets are unavoidable:
- Create and copy them manually, as needed.
- This should be rare enough that manual management isn't onerous.
- No secrets committed to the repository (encrypted or otherwise).

## Observability

Moving toward an **OpenTelemetry + OpenObserve** stack. See `hosts/mon/` for the current
implementation.

## Data Storage & Backups

- **Per-machine:** btrfs with `btrbk` for local snapshots.
- **Off-machine:** backups to a NAS, plus `restic` to blob storage.
- Services that need persistence use virtiofs shares to their microvm host, where the
  host's btrfs + btrbk handles snapshotting.
- No clustered/distributed filesystems: each machine manages its own storage.

## Uniformity

Prefer consistency across machines. If a pattern works on one host, use it everywhere
unless there's a concrete reason not to.

- Shared configuration lives in `modules/` and is imported by hosts that need it.
- Host-specific configuration in `hosts/<name>/` should be minimal: mostly the set of
  services and network addresses.
- Every host uses the same NixOS channel (pinned in `flake.lock`), the same comin
  deployment mechanism, and the same base modules.
