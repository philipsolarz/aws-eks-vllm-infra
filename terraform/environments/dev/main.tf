terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.86.1"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../modules/vpc"

  region               = var.region
  environment          = var.environment
  cidr_block           = var.cidr_block
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags

}

module "eks" {
  source = "../../modules/eks"

  region             = var.region
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  cluster_version = var.cluster_version

  default_ami_type       = var.default_ami_type
  default_instance_types = var.default_instance_types
  default_scaling_config = var.default_scaling_config

  gpu_ami_type       = var.gpu_ami_type
  gpu_instance_types = var.gpu_instance_types
  gpu_scaling_config = var.gpu_scaling_config

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  depends_on = [module.vpc]
}

data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}


module "helm" {
  source = "../../modules/helm"

  external_secrets_role_arn = module.eks.external_secrets_role_arn
  karpenter_role_arn        = module.eks.karpenter_role_arn

  depends_on = [module.eks]
}
