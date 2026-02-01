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

output "reserved_public_ip_id" {
  description = "Reserved public IP OCID for Traefik."
  value       = oci_core_public_ip.reserved.id
}
