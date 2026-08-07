# Threat Model

## Assets

Typical homelab assets: personal documents, home automation control, media, network
infrastructure. No extraordinary secrets, the primary concern is maintaining control and
privacy of a home network, not protecting classified data.

## Adversaries

- **Opportunistic remote attackers**: scanning for exposed/vulnerable services, exploiting
  unpatched CVEs, credential stuffing. The most likely threat.
- **Targeted remote attackers**: someone specifically interested in this network. Less
  likely, but the design should make lateral movement hard even if an initial service is
  compromised.
- **Supply chain attackers**: compromised upstream dependencies, malicious NixOS module
  updates.

Physical access and insider threats are out of scope.

## Attack Surfaces & Mitigations

### 1. Remote exploitation of exposed services

Exposed services are the primary attack surface. Mitigations, in order of preference:

| Priority | Mechanism | When |
|----------|-----------|------|
| 1 (ideal) | **mTLS** | When clients support it |
| 2 | **oauth2-proxy** | Web services that don't natively support strong auth |
| 3 | **OIDC (native)** | Services with a good security reputation and built-in OIDC |
| 4 (last resort) | **WireGuard** | When nothing else fits; at least limits exposure to the VPN |

**Principle: every incoming request must be authenticated.** Applications are not trusted to
implement authentication correctly: always front them with one of the above.

**Memory safety:** avoid memory-unsafe services (C/C++) for anything exposed to untrusted
input. Prefer Rust or Go. Other memory-safe languages are acceptable if the service has a
strong security track record.

**Root privilege:** exposed services must not run as root, especially on important machines.
Use `DynamicUser` / `User=` in systemd units.

### 2. Lateral movement

If an attacker compromises one service, they should not easily reach others.

- **Within a machine:** services are isolated from each other using `microvm.nix` guests
  for different trust domains. Linux containers are explicitly **not** trusted as a
  sandbox boundary.
- **Across machines:** each host should be independently secured. An attacker who owns one
  machine should not gain access to others by default. Avoid cross-machine trust
  relationships where possible.
- The NixOS **host/hypervisor** is part of the TCB.

### 3. Supply chain

- **Applications:** run with least privilege (`DynamicUser`, minimal filesystem access,
  restricted capabilities).
- **NixOS modules:** avoid adopting new flakes, especially on high-trust machines (laptop,
  primary hosts). Prefer modules already in nixpkgs or from well-established sources.
- **Git integrity:** `gittuf` is used to verify commits before comin deploys them (see
  `modules/comin/`). This protects against compromise of the git remote.
- **Pinned inputs:** `flake.lock` pins all dependencies.

### 4. Host/guest boundary

- KVM/microvm is the isolation boundary between trust domains. The hypervisor is trusted.
- Services that need to share a trust domain can run on the same host or same microvm.
- Services in different trust domains get separate microvms.
