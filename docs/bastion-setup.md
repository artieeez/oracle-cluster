# Bastion Setup (OKE)

This guide links to the official OCI documentation for setting up a bastion to access a private Kubernetes API endpoint and worker nodes.

## Official guide
- https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm

## High-level steps
1. Create a bastion subnet in the same VCN.
2. Add security list rules to allow TCP/6443 to the Kubernetes API endpoint subnet.
3. Create a bastion and a port-forwarding session to the API endpoint.
4. Update kubeconfig to point to `https://127.0.0.1:6443` and establish the SSH tunnel.
