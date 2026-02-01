variable "tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
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
