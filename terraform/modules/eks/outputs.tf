output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "EKS Cluster endpoint URL."
  value       = aws_eks_cluster.eks.endpoint
}
