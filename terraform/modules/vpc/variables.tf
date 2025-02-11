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

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
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
