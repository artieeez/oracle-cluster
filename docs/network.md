# Network Configuration Overview

This document summarizes the Terraform network setup used by the OKE cluster.

## VCN

- **VCN CIDR:** `var.vcn_cidr`
- **Gateways:** Internet Gateway, NAT Gateway, Service Gateway (Oracle Services Network).
- **Routing:** Public route table uses the Internet Gateway; private route table uses NAT for internet egress and Service Gateway for OCI service access.

## Subnets

### Public Subnet (`var.public_subnet_cidr`)

**Primary use**

- OKE cluster public API endpoint.
- The Terraform-managed Traefik NLB (HTTP, HTTPS, games).

**Key attributes**

- Public IPs allowed on VNICs.
- Route table: `public` (0.0.0.0/0 via Internet Gateway).
- Security lists: default VCN security list + `public_api` security list.

**Traffic allowed**

- **Ingress TCP 80 and 443** from `0.0.0.0/0` (Traefik NLB).
- **Ingress TCP 6443** from `var.api_public_allowed_cidrs` (Kubernetes API).
- **Ingress TCP 6443, 2379-2380, 10250, 10257, 10259** from `var.private_subnet_cidr` (control plane ports).
- **Egress:** all protocols to `0.0.0.0/0`.

**Traffic blocked/limited**

- No other explicit inbound rules in this module; anything not in the security lists is blocked.
- **No DNS.** TCP/UDP 53 and 853 are not published on the NLB (see [ADR 002](./adr/002-close-public-dns.md)).

### Private Subnet (`var.private_subnet_cidr`)

**Primary use**

- OKE worker nodes (node pool placement configs).

**Key attributes**

- Public IPs prohibited on VNICs.
- Route table: `private` (0.0.0.0/0 via NAT; OCI services via Service Gateway).
- Security lists: `nodeports` security list.

**Traffic allowed (via NSGs and security lists)**

- **Ingress from VCN:** all protocols from within the VCN CIDR.
- **Ingress SSH:** TCP 22 from `var.ssh_allowed_cidrs`.
- **Ingress NodePort range:** TCP/UDP 30000-32767 from `var.public_subnet_cidr` (security list) and from `0.0.0.0/0` on the nodes NSG. The subnet is private, so this is reachable only through the NLB.
- **Ingress to API endpoint:** node-to-endpoint TCP 6443 (via endpoint NSG).
- **Ingress kube-proxy:** TCP 12250 between endpoint and node NSGs.
- **Egress:** all protocols to `0.0.0.0/0`.

**Traffic blocked/limited**

- No direct internet ingress (private subnet, no public IPs).

## Traefik network load balancer

- Public NLB on the public subnet, attached to the reserved public IP (`reserved_public_ip_address` output), port `80`/`443`/`25565` listeners only.
- Traffic restricted by the `traefik_nlb` NSG: TCP 80, 443 and 25565 from `0.0.0.0/0`; egress all.
- Backends are the node pool's private IPs, one backend set per listener, `FIVE_TUPLE` policy with source preservation.
- **DNS is intentionally absent:** Pi-hole is reached over the tailnet (`pihole-dns.<tailnet>.ts.net`), never through the NLB. Rationale and trade-offs in [ADR 002](./adr/002-close-public-dns.md).

## Security Controls Summary

- **Security Lists:** public subnet allows TCP 80/443 from `0.0.0.0/0` and TCP 6443 from allowed CIDRs; private subnet allows the NodePort range from the public subnet.
- **Network Security Groups (NSGs):**
  - Endpoint NSG: allows TCP 6443 from `api_public_allowed_cidrs` and nodes; allows TCP 12250 from nodes; egress all.
  - Nodes NSG: allows all from VCN, SSH from `ssh_allowed_cidrs`, TCP 12250 from endpoint; egress all.
  - Traefik NLB NSG: allows TCP 80, 443 and 25565 from `0.0.0.0/0`; egress all.
