variable "tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version or 'latest'."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for node access."
  type        = string
}

variable "node_pool_size" {
  description = "Number of nodes in the pool."
  type        = number
}

variable "vcn_id" {
  description = "VCN OCID."
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet OCID."
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet OCID."
  type        = string
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block."
  type        = string
}

variable "api_public_allowed_cidrs" {
  description = "CIDR blocks allowed to access the public Kubernetes API endpoint."
  type        = list(string)
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into nodes."
  type        = list(string)
}
