output "cluster_id" {
  description = "OKE cluster OCID."
  value       = oci_containerengine_cluster.oke.id
}

output "node_pool_id" {
  description = "OKE node pool OCID."
  value       = oci_containerengine_node_pool.oke.id
}

output "cluster_private_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = oci_containerengine_cluster.oke.endpoints[0].private_endpoint
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint."
  value       = oci_containerengine_cluster.oke.endpoints[0].public_endpoint
}

output "traefik_nlb_id" {
  description = "OCID of the Terraform-managed Traefik NLB."
  value       = oci_network_load_balancer_network_load_balancer.traefik.id
}

output "traefik_nlb_public_ip_addresses" {
  description = "Public IP addresses currently assigned to the Terraform-managed Traefik NLB."
  value       = oci_network_load_balancer_network_load_balancer.traefik.ip_addresses
}
