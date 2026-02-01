# Oracle OKE Terraform

This repository contains Terraform code to create an OKE cluster with a node pool in the Oracle Cloud Infrastructure (OCI).

## Setup summary
Setting up the cluster consists of:

Prerequisites:
- Oracle Cloud account in your target region
- Terraform installed
- OCI CLI installed

Steps:
- Fill `terraform.tfvars`
- Run `terraform init`
- Apply resources with `terraform apply`
- Set up bastion and kubectl access

## Authentication (recommended)
Use the OCI CLI to create the `~/.oci/config` profile and keys that Terraform uses.

1. Install the OCI CLI:
   - `brew install oci-cli`
2. Generate config and keys:
   - `oci setup config`
3. In the OCI Console, add the generated public key:
   - User -> API Keys -> Add API Key
4. Ensure your user has permissions in the root compartment.

Terraform will read the profile from `~/.oci/config` (default profile name is `DEFAULT`).

## Run Terraform
Example:

```
terraform init
terraform plan \
  -var tenancy_ocid="ocid1.tenancy..." \
  -var ssh_public_key_path="$HOME/.ssh/id_rsa.pub" \
  -var 'bastion_allowed_cidrs=["YOUR.IP/32"]' \
  -var 'ssh_allowed_cidrs=["YOUR.IP/32"]' \
  -var region="sa-vinhedo-1"
```

## Configure kubectl
Generate kubeconfig using the cluster output:

```
oci ce cluster create-kubeconfig \
  --cluster-id <cluster_ocid> \
  --file $HOME/.kube/config \
  --region <region> \
  --token-version 2.0.0 \
  --kube-endpoint PRIVATE_ENDPOINT
```

This project provisions an OCI Bastion Service in the public subnet and keeps
the Kubernetes API endpoint private. Access to the API is only allowed from the
bastion subnet and worker nodes inside the VCN. Use the bastion session to set
up a local port forward before running `kubectl`.

Get the bastion SSH command:

```
terraform output -raw bastion_session_get_command
```

Run the command it prints to open the tunnel, then set the kubeconfig server to
`https://127.0.0.1:6443`.

Test access:

```
kubectl get nodes
```

If using a bastion with port forwarding, set the kubeconfig server to `https://127.0.0.1:6443` and use the SSH tunnel from the bastion session before running `kubectl`.

Rename the context to something memorable:

```
kubectl config rename-context <old_context_name> <new_context_name>
```

## Additional documentation
- https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm
