output "vcn_id" {
  description = "VCN OCID."
  value       = oci_core_vcn.oke.id
}

output "public_subnet_id" {
  description = "Public subnet OCID."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet OCID."
  value       = oci_core_subnet.private.id
}

output "bastion_subnet_id" {
  description = "Bastion subnet OCID."
  value       = oci_core_subnet.bastion.id
}
