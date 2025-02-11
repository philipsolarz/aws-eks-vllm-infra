module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.region}-${var.environment}-vpc"
  cidr = var.cidr_block

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    "Name" = "${var.region}-${var.environment}-vpc"
  }

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  enable_vpn_gateway = var.enable_vpn_gateway

  public_subnet_tags = var.public_subnet_tags

  private_subnet_tags = var.private_subnet_tags
}
