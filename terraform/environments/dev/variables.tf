variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN gateway"
  type        = bool
  default     = true
}

variable "public_subnet_tags" {
  description = "Tags for public subnets"
  type        = map(string)
  default = {
    "kubernetes.io/role/elb" = "1"
  }
}

variable "private_subnet_tags" {
  description = "Tags for private subnets"
  type        = map(string)
  default = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
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
