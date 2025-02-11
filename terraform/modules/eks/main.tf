module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.region}-${var.environment}-eks"
  cluster_version = var.cluster_version

  cluster_addons = var.cluster_addons

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  eks_managed_node_groups = {
    default = {
      ami_type       = var.default_ami_type
      instance_types = var.default_instance_types

      min_size     = var.default_scaling_config.min
      max_size     = var.default_scaling_config.max
      desired_size = var.default_scaling_config.desired

    },
    # gpu = {
    #   ami_type       = var.gpu_ami_type
    #   instance_types = var.gpu_instance_types

    #   min_size     = var.gpu_scaling_config.min
    #   max_size     = var.gpu_scaling_config.max
    #   desired_size = var.gpu_scaling_config.desired

    # }
  }

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
}


