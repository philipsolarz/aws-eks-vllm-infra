# variable "kubernetes_api_endpoint" {
#   description = "The public API endpoint of the Kubernetes cluster"
#   type        = string
# }


variable "external_secrets_role_arn" {
  description = "The ARN of the IAM role to associate with the external-secrets service account"
  type        = string
}

variable "karpenter_role_arn" {
  description = "The ARN of the IAM role to associate with the karpenter service account"
  type        = string
}
