# ADR 002: Close the public DNS path on the Traefik NLB

Status: Accepted · 2026-11-02

## Context

Pi-hole runs in the cluster and was reachable from the internet through the
Traefik NLB: `dns-tcp-53`, `dns-udp-53` and `dot-tcp-853` listeners forwarding to
Traefik NodePorts, then to the `pihole-dns` service. Access was never public —
`var.dns_server_allowed_cidrs` gated TCP/UDP 53 on the public-subnet security
list, TCP 53 and 853 on the Traefik NLB NSG, and the NLB listeners always existed
regardless of that list.

That allowlist was a list of `/32` home and mobile WAN addresses, which change
whenever the ISP reassigns them. Keeping the path usable meant editing
`terraform.tfvars` (gitignored, so also the CI mirror in
`.github/workflows/nightly-plan.yml`) every time an address rotated.

Since the `tailscale-pihole` work (`artr-gitops`), Pi-hole is also a tailnet
device (`pihole-dns`, `100.100.245.12`) and the tailnet is the configured global
resolver for the MacBook and Android phone. The public path stopped being the
primary one.

Evidence gathered while deciding (2026-11-02, read-only):

- Live OCI security lists and NLB NSG allowed 53 from `189.6.241.123/32`,
  `179.68.24.174/32`, `189.6.246.42/32` and `189.6.246.151/32` — none of them the
  current home address (`189.6.244.220`, which *is* allowed for the Kubernetes
  API on 6443). Public DNS was therefore already unreachable from home, and had
  been long enough that nobody noticed.
- The live `traefik-oci` Service exposes `53/TCP` (nodePort 32054), `853/TCP`,
  `80` and `443` — but **no** `53/UDP` port, even though the NLB `dns-udp-53`
  listener targets node port 32053. UDP DNS through the NLB was already broken
  for every source, allowed or not.
- The NLB keeps `is-preserve-source: true`, so Pi-hole would have logged the real
  client address; no evidence of an external consumer survived the rotation
  churn.

The only documented consumer was the home router
(`apps/platform/pihole/README.md`: "Point your router's DNS to the Traefik NLB
IP"), and that instruction is now satisfied by the tailnet path instead.

## Decision

Do not publish DNS on the public NLB. Remove the `:53` TCP/UDP and `:853` DoT
listeners, backend sets, backends, NLB NSG rules and public-subnet security-list
rules, and delete `var.dns_server_allowed_cidrs`. Pi-hole is reached over the
tailnet only; the NLB keeps serving HTTP, HTTPS and the games listener.

## Why not keep the path and add the current IP

- The address is dynamic, so "add my IP" recurs forever — and each reversal
  requires a `terraform apply` from a machine whose IP is already allowlisted for
  the API, or a CI run.
- Stale `/32`s are a silent liability: once the ISP reassigns one, it belongs to
  somebody else. Four dead entries were live; any of them could have given a
  stranger a resolver inside the VCN.
- A public, if firewalled, DNS surface is the one thing that needs to be *open*
  to the internet to be useful, which makes it the wrong thing to keep around
  when a private path already exists.

## Consequences

- Household clients that used the public NLB IP as their resolver must move to
  the tailnet (`pihole-dns.<tailnet>.ts.net`) or to another resolver. This is not
  a behaviour change today: the current home address was not in the allowlist.
- DoT on `:853` disappears as well. It shared the same variable and the same
  Pi-hole; leaving it behind would have kept the rotation churn for a single
  port. Android clients that pinned `pihole.artr.com.br` as Private DNS must use
  Tailscale DNS instead (already required by
  `artr-gitops/docs/tailscale-pihole-setup.md`).
- Traefik still has `dnsudp` / `dnstcp` / `dottcp` entryPoints and NodePorts in
  `artr-gitops/charts/traefik-values.yaml`. They are now unreachable from the
  internet but harmless; removing them is a separate GitOps change.
- Reversing this decision means restoring the removed resources from git and a
  `terraform apply`. No state migration is involved.

## Gotchas worth remembering

- `terraform.tfvars` and the `TF_VAR_*` mirror in `nightly-plan.yml` must both
  lose `dns_server_allowed_cidrs`; the workflow would otherwise feed an undeclared
  variable and the nightly plan would drift from reality.
- The NLB allows only one backend mutation at a time, so the `depends_on` chains
  between backend sets, backends and listeners are intentional — re-chain them
  (`http → https → minecraft`) instead of deleting them when resources move.
