output "cluster_id" {
  description = "OKE cluster OCID."
  value       = module.oke.cluster_id
}

output "node_pool_id" {
  description = "OKE node pool OCID."
  value       = module.oke.node_pool_id
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig for the cluster."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint."
  value       = module.oke.cluster_public_endpoint
}

output "cluster_private_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = module.oke.cluster_private_endpoint
}

output "reserved_public_ip_id" {
  description = "Reserved public IP OCID for Traefik."
  value       = module.network.reserved_public_ip_id
}

output "reserved_public_ip_address" {
  description = "Reserved public IP address for Traefik."
  value       = module.network.reserved_public_ip_address
}

output "db_volume_id" {
  description = "OCID of the 50 GB block volume for database use."
  value       = oci_core_volume.db_volume.id
}

output "db_volume_availability_domain" {
  description = "Availability domain of the DB block volume (for attachment)."
  value       = oci_core_volume.db_volume.availability_domain
}
