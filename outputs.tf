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

output "public_subnet_id" {
  description = "Public subnet OCID (use for Traefik NLB subnet annotation)."
  value       = module.network.public_subnet_id
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

output "traefik_nlb_id" {
  description = "OCID of the Terraform-managed Traefik NLB."
  value       = module.oke.traefik_nlb_id
}

output "traefik_nlb_public_ip_addresses" {
  description = "Public IP addresses currently assigned to the Terraform-managed Traefik NLB."
  value       = module.oke.traefik_nlb_public_ip_addresses
}

output "sitio_dashboard_repository_name" {
  description = "OCI Container Registry repository name for sitio-dashboard."
  value       = oci_artifacts_container_repository.sitio_dashboard.display_name
}

output "sitio_dashboard_repository_url" {
  description = "OCI Container Registry repository URL for sitio-dashboard."
  value       = "${var.region}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${oci_artifacts_container_repository.sitio_dashboard.display_name}"
}

output "sitio_backend_repository_name" {
  description = "OCI Container Registry repository name for sitio-backend."
  value       = oci_artifacts_container_repository.sitio_backend.display_name
}

output "sitio_backend_repository_url" {
  description = "OCI Container Registry repository URL for sitio-backend."
  value       = "${var.region}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${oci_artifacts_container_repository.sitio_backend.display_name}"
}
