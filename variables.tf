variable "tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
}

variable "region" {
  description = "OCI region."
  type        = string
  default     = "us-ashburn-1"
}

variable "home_region" {
  description = "OCI home region for identity operations (policies)."
  type        = string
  default     = "sa-vinhedo-1"
}

variable "oci_profile" {
  description = "Profile name in ~/.oci/config."
  type        = string
  default     = "DEFAULT"
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
  default     = "oke-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version or 'latest'."
  type        = string
  default     = "latest"
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block."
  type        = string
  default     = "10.0.1.0/24"
}

variable "bastion_subnet_cidr" {
  description = "Bastion subnet CIDR block."
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_allowed_cidrs" {
  description = "CIDR allowlist for bastion sessions."
  type        = list(string)
  default     = []
}

variable "bastion_ssh_public_key_path" {
  description = "Path to the SSH public key for bastion sessions."
  type        = string
}

variable "iam_admin_group_name" {
  description = "IAM group name for bastion permissions."
  type        = string
  default     = "Administrators"
}

variable "iam_tenancy_name" {
  description = "Tenancy name used in IAM policy statements."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into nodes."
  type        = list(string)
  default     = []
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for node access."
  type        = string
}

variable "node_pool_size" {
  description = "Number of nodes in the pool."
  type        = number
  default     = 2
}
