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
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint."
  value       = module.oke.cluster_public_endpoint
}

output "cluster_private_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = module.oke.cluster_private_endpoint
}

output "bastion_id" {
  description = "Bastion OCID."
  value       = module.bastion.bastion_id
}

output "bastion_session_id" {
  description = "Bastion session OCID for API port forwarding."
  value       = module.bastion.bastion_session_id
}
