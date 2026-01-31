# Oracle OKE Terraform

This repository contains Terraform code to create an OKE cluster with a node pool in the Oracle Cloud Infrastructure (OCI).

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
  -var 'api_allowed_cidrs=["YOUR.IP/32"]' \
  -var 'ssh_allowed_cidrs=["YOUR.IP/32"]'
```
