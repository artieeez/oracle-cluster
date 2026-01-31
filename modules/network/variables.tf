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

variable "bastion_subnet_cidr" {
  description = "Bastion subnet CIDR block."
  type        = string
}
