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


# resource "aws_eks_addon" "pod_identity" {
#   cluster_name  = module.eks_cluster.cluster_name
#   addon_name    = "eks-pod-identity-agent"
#   addon_version = "v1.3.4-eksbuild.1"
# }


data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "aws_lbc" {
  name               = "${module.eks_cluster.cluster_name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}


resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = module.eks_cluster.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}

data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${module.eks_cluster.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_iam_policy" "abs_csi_driver_encryption" {
  name = "${module.eks_cluster.cluster_name}-ebs-csi-driver-encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption" {
  policy_arn = aws_iam_policy.abs_csi_driver_encryption.arn
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = module.eks_cluster.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks_cluster.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.39.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [module.eks_cluster]
}
