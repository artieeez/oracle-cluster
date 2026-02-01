# OCI monthly cost analysis (oracle-cluster)

This document estimates the likely monthly costs for the resources defined in this repo. Prices vary by region and by usage, so treat this as a model you can plug current OCI price list values into.

## Free tier notes for `us-ashburn-1`

Based on your inputs:

- **Compute free tier:** 4 OCPUs and 24 GB RAM total, split across up to 4 instances.
- **Block storage free tier:** 200 GB total.
- **OKE control plane:** free.

Implication for this repo's defaults (2 nodes @ 2 OCPU / 12 GB each):

- Compute totals are **4 OCPU / 24 GB**, which fits the free tier if no other compute is running.
- Boot volumes **count toward** the 200 GB block storage free tier.
- If the sum of all block volumes (boot + any data volumes) stays within 200 GB, storage can be free.

## Resource inventory (from Terraform)

Created by modules in this repo:

- OKE cluster control plane (public endpoint enabled)
- Node pool: `VM.Standard.A1.Flex` with `2 OCPUs` and `12 GB` RAM per node
- VCN + public/private subnets
- Internet gateway, NAT gateway, service gateway
- Network security groups and security lists
- Reserved public IP (intended for Traefik)

Default node pool size is `2` unless overridden in `terraform.tfvars`.

## Cost drivers and formulas

Use `hours_per_month = 730` for a typical month.

### 1) Compute (node pool)

Largest cost driver. For each node:

```
node_hourly = (ocpu_price_per_hour * 2) + (memory_price_per_gb_hour * 12)
monthly_compute = node_hourly * node_pool_size * hours_per_month
```

Notes:
- Shape is `VM.Standard.A1.Flex` with 2 OCPU and 12 GB RAM per node.
- If total OCPU <= 4 and total RAM <= 24 GB in `us-ashburn-1`, compute can be free.
- If you scale the node pool above free tier limits, costs scale linearly.

### 2) Boot volumes (node pool)

OKE nodes create a boot volume per node (size depends on the image/defaults).

```
monthly_boot_volumes = boot_volume_gb * boot_volume_price_per_gb_month * node_pool_size
```

Notes:
- Check actual boot volume size in the OCI console for the node pool.
- In `us-ashburn-1`, boot volumes count toward the 200 GB block storage free tier.

### 3) NAT gateway

NAT gateway has an hourly charge plus data processing charges.

```
monthly_nat = nat_hourly_price * hours_per_month
            + nat_data_gb * nat_data_price_per_gb
```

Notes:
- Any egress from private subnet to the internet goes through NAT.

### 4) Public IP (reserved)

Reserved public IPs are typically free when attached to a resource and billed when unattached.

```
monthly_public_ip = (is_unattached ? public_ip_hourly_price * hours_per_month : 0)
```

### 5) OKE control plane

In `us-ashburn-1` (per your note), the OKE control plane is free.

```
monthly_control_plane = 0
```

### 6) Data egress

Outbound internet egress is charged (from public nodes, public load balancers, or NAT).

```
monthly_egress = egress_gb * egress_price_per_gb
```

## Low-level resources that are typically free

These resources generally do not have direct hourly charges:

- VCN, subnets, route tables
- Security lists and NSGs
- Internet gateway
- Service gateway

They still indirectly affect cost via data transfer and NAT usage.

## Quick monthly estimate template

Fill in current prices and usage:

```
hours_per_month = 730
node_pool_size = <var.node_pool_size>

monthly_total =
  monthly_compute
  + monthly_boot_volumes
  + monthly_nat
  + monthly_public_ip
  + monthly_control_plane
  + monthly_egress
```

## How to validate actuals

- OCI Console: `Billing & Cost Management` -> `Cost Analysis`
- Filter by compartment and service (Compute, OKE, Networking)
- Compare actuals to the formulas above

## Assumptions

- Nodes run 24/7 for the full month.
- No autoscaling beyond `node_pool_size`.
- No additional services (e.g., Load Balancers from Kubernetes `Service` of type `LoadBalancer`).
- Free tier limits apply only if **total tenancy usage** stays within the stated caps.

If you want a more precise estimate, share your region, node pool size, and any extra services running in the cluster.
