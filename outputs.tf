output "cluster_id" {
  description = "OKE cluster OCID."
  value       = oci_containerengine_cluster.oke.id
}

output "node_pool_id" {
  description = "OKE node pool OCID."
  value       = oci_containerengine_node_pool.oke.id
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig for the cluster."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oke.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint."
  value       = oci_containerengine_cluster.oke.endpoints[0].public_endpoint
}
