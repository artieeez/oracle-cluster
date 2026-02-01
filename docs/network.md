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
- Service load balancers for Kubernetes services.

**Key attributes**
- Public IPs allowed on VNICs.
- Route table: `public` (0.0.0.0/0 via Internet Gateway).
- Security lists: default VCN security list + `public_api` security list.

**Traffic allowed**
- **Ingress:** TCP 6443 from `var.api_public_allowed_cidrs` (Kubernetes API).
- **Egress:** All protocols to `0.0.0.0/0`.

**Traffic blocked/limited**
- No other explicit inbound rules in this module; anything not in the security lists is blocked.

### Private Subnet (`var.private_subnet_cidr`)

**Primary use**
- OKE worker nodes (node pool placement configs).

**Key attributes**
- Public IPs prohibited on VNICs.
- Route table: `private` (0.0.0.0/0 via NAT; OCI services via Service Gateway).
- Security lists: default VCN security list only.

**Traffic allowed (via NSGs)**
- **Ingress from VCN:** all protocols from within the VCN CIDR.
- **Ingress SSH:** TCP 22 from `var.ssh_allowed_cidrs`.
- **Ingress to API endpoint:** node-to-endpoint TCP 6443 (via endpoint NSG).
- **Ingress kube-proxy:** TCP 12250 between endpoint and node NSGs.
- **Egress:** all protocols to `0.0.0.0/0`.

**Traffic blocked/limited**
- No direct internet ingress (private subnet, no public IPs).

## Security Controls Summary

- **Security Lists:** public subnet adds a dedicated security list allowing TCP 6443 from allowed CIDRs.
- **Network Security Groups (NSGs):**
  - Endpoint NSG: allows TCP 6443 from `api_public_allowed_cidrs` and nodes; allows TCP 12250 from nodes; egress all.
  - Nodes NSG: allows all from VCN, SSH from `ssh_allowed_cidrs`, TCP 12250 from endpoint; egress all.

