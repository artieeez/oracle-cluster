output "bastion_id" {
  description = "Bastion OCID."
  value       = oci_bastion_bastion.oke.id
}

output "bastion_session_id" {
  description = "Bastion session OCID for API port forwarding."
  value       = oci_bastion_session.oke_k8s_api.id
}
