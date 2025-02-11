output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster endpoint URL."
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS Cluster certificate authority data."
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "asd" {
  description = "EKS Cluster certificate authority data."
  value       = module.eks_cluster.cluster_a
}
