# Network Diagram

![Network diagram](NETWORK.svg)

Source: [network.dot](network.dot)

## Security details

- **redbox is the perimeter firewall** (nftables, `filterForward = true`, default-deny).
  LAN hosts have global IPv6 addresses, but inbound is blocked unless it matches a forward
  rule. Inbound `extraForwardRules` (hosts/redbox/default.nix:64):
  - **all IPv6** → aluminium's VM subnet `2401:dc20:262f:20::/60` (the microvms)
  - **443/tcp** → aluminium (HTTPS; IPv4 clients reach it via snid NAT46)
  - **51820/udp** → aluminium and platinum (WireGuard)
- **Everything else is dropped**, including all inbound to oxygen, rockpro64, and the
  family devices. IPv4 for LAN hosts is outbound-only NAT (`networking.nat`); the only
  IPv4 ingress anywhere is snid on redbox.
- **Microvms have no more LAN access than the public internet does.** They sit on the
  routed subnet `2401:dc20:262f:20::/60`, so there's no L2 adjacency to LAN hosts, and
  policy routing (`hosts/aluminium/microvm-host.nix`) forces all VM traffic through
  redbox's firewall rather than straight to LAN clients. Inbound to a VM is governed by
  exactly the same `extraForwardRules` as any external client, and VM→LAN traffic is
  dropped by default-deny. A VM compromise should not gain it access to oxygen,
  rockpro64, or the family devices.
- The **WireGuard mesh (`192.168.2.0/24`)** is the control plane joining redbox,
  aluminium, platinum, oxygen, and strontium. NFS mounts (platinum as server) and MQTT
  run over it.
- **strontium** is a public authoritative DNS server (Knot, catalog zones), reachable
  over IPv6 and over the WireGuard mesh (DoT on `192.168.2.7:853`).
- **argon** is a standalone Oracle OCI VM with an exposed sshd; it is not in the
  WireGuard mesh.

> Note: the diagram shows microvms only on aluminium, matching the current repo. If
> platinum is meant to host VMs too (and have a `/60` forwarded to it), that config isn't
> in `hosts/redbox` yet.
