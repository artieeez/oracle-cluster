variable "tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
}

variable "bastion_subnet_id" {
  description = "Bastion subnet OCID."
  type        = string
}

variable "bastion_allowed_cidrs" {
  description = "CIDR allowlist for bastion sessions."
  type        = list(string)
}

variable "bastion_ssh_public_key_path" {
  description = "Path to the SSH public key for bastion sessions."
  type        = string
}

variable "target_resource_id" {
  description = "Target resource OCID for the bastion session."
  type        = string
}

variable "target_private_ip" {
  description = "Target private IP for the bastion session."
  type        = string
}

variable "target_port" {
  description = "Target port for the bastion session."
  type        = number
}
