# Network Diagram

![Network diagram](NETWORK.svg)

Source: [network.dot](network.dot)

## Security details

- **redbox is the perimeter firewall** (nftables, `filterForward = true`, default-deny).
  LAN hosts have global IPv6 addresses, but inbound is blocked unless it matches a forward
  rule. Inbound `extraForwardRules` (hosts/redbox/default.nix):
  - **51820/udp** → aluminium and platinum (WireGuard)
- **Everything else is dropped**, including all inbound to oxygen, rockpro64, and the
  family devices. IPv4 for LAN hosts is outbound-only NAT (`networking.nat`); there is no
  IPv4 ingress.
- The **WireGuard mesh (`192.168.2.0/24`)** is the control plane joining redbox,
  aluminium, platinum, oxygen, and strontium. NFS mounts (platinum as server) run
  over it.
- **argon** is a standalone Oracle OCI VM with an exposed sshd; it is not in the
  WireGuard mesh.
