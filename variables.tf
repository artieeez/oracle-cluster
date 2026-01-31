variable "tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
}

variable "region" {
  description = "OCI region."
  type        = string
  default     = "us-ashburn-1"
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

variable "api_allowed_cidrs" {
  description = "Additional CIDR blocks allowed to access the Kubernetes API endpoint."
  type        = list(string)
  default     = []
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
