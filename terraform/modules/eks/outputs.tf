output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "EKS Cluster endpoint URL."
  value       = aws_eks_cluster.eks.endpoint
}

output "external_secrets_role_arn" {
  description = "The ARN of the IAM role to associate with the external-secrets service account"
  value       = aws_iam_role.external_secrets.arn
}

output "karpenter_role_arn" {
  description = "The ARN of the IAM role to associate with the external-secrets service account"
  value       = aws_iam_role.karpenter_controller.arn
}
