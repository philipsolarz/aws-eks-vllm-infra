variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "cluster_addons" {
  description = "Map of cluster addons to enable"
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster endpoint"
  type        = bool
  default     = true
}

variable "default_ami_type" {
  description = "AMI type for the default EKS managed node group"
  type        = string
}

variable "default_instance_types" {
  description = "List of EC2 instance types for the default EKS managed node group"
  type        = list(string)
}

variable "default_scaling_config" {
  description = "Scaling configuration for the default EKS managed node group"
  type = object({
    min     = number
    max     = number
    desired = number
  })
}

variable "gpu_ami_type" {
  description = "AMI type for the GPU EKS managed node group"
  type        = string
}

variable "gpu_instance_types" {
  description = "List of EC2 instance types for the GPU EKS managed node group"
  type        = list(string)
}

variable "gpu_scaling_config" {
  description = "Scaling configuration for the GPU EKS managed node group"
  type = object({
    min     = number
    max     = number
    desired = number
  })
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable admin permissions for the cluster creator"
  type        = bool
  default     = true
}
