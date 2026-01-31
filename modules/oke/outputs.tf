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
