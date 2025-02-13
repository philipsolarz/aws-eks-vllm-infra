resource "aws_iam_role" "eks" {
  name = "${var.region}-${var.environment}-eks"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
  name     = "${var.region}-${var.environment}-eks"
  version  = var.cluster_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = var.private_subnet_ids
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks]
}

resource "aws_iam_role" "nodes" {
  name = "${var.region}-${var.environment}-eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = var.cluster_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids     = var.private_subnet_ids
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.large"]

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.eks.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.4-eksbuild.1"
  # Implicitly depends on aws_eks_cluster via cluster_name
}

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
  name               = "${aws_eks_cluster.eks.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}

resource "aws_iam_policy" "aws_lbc" {
  policy = file("${path.module}/policies/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}

resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn

  depends_on = [aws_iam_role_policy_attachment.aws_lbc]
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
  name               = "${aws_eks_cluster.eks.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_iam_policy" "abs_csi_driver_encryption" {
  name = "${aws_eks_cluster.eks.name}-ebs-csi-driver-encryption"

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
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver,
    aws_iam_role_policy_attachment.ebs_csi_driver_encryption,
  ]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.39.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    aws_eks_pod_identity_association.ebs_csi_driver,
  ]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  depends_on = [aws_eks_cluster.eks]
}

data "aws_iam_policy_document" "secrets_store_csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:secrets-store-csi-driver"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
  }
}

resource "aws_iam_role" "secrets_store_csi" {
  name               = "${aws_eks_cluster.eks.name}-secrets-store-csi"
  assume_role_policy = data.aws_iam_policy_document.secrets_store_csi.json

  depends_on = [aws_iam_openid_connect_provider.eks]
}

resource "aws_iam_policy" "secrets_store_csi" {
  name = "${aws_eks_cluster.eks.name}-secrets-store-csi-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_store_csi" {
  role       = aws_iam_role.secrets_store_csi.name
  policy_arn = aws_iam_policy.secrets_store_csi.arn
}

output "secrets_store_csi_role_arn" {
  value = aws_iam_role.secrets_store_csi.arn
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${aws_eks_cluster.eks.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets.json

  depends_on = [aws_iam_openid_connect_provider.eks]
}

resource "aws_iam_policy" "external_secrets" {
  name = "${aws_eks_cluster.eks.name}-external-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}











# # module "eks_cluster" {
# #   source  = "terraform-aws-modules/eks/aws"
# #   version = "~> 20.0"

# #   cluster_name    = "${var.region}-${var.environment}-eks"
# #   cluster_version = var.cluster_version

# #   cluster_addons = var.cluster_addons

# #   vpc_id     = var.vpc_id
# #   subnet_ids = var.private_subnet_ids

# #   cluster_endpoint_public_access  = var.cluster_endpoint_public_access
# #   cluster_endpoint_private_access = var.cluster_endpoint_private_access

# #   eks_managed_node_groups = {
# #     default = {
# #       ami_type       = var.default_ami_type
# #       instance_types = var.default_instance_types

# #       min_size     = var.default_scaling_config.min
# #       max_size     = var.default_scaling_config.max
# #       desired_size = var.default_scaling_config.desired

# #     },
# #     # gpu = {
# #     #   ami_type       = var.gpu_ami_type
# #     #   instance_types = var.gpu_instance_types

# #     #   min_size     = var.gpu_scaling_config.min
# #     #   max_size     = var.gpu_scaling_config.max
# #     #   desired_size = var.gpu_scaling_config.desired

# #     # }
# #   }

# #   enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
# # }

# resource "aws_iam_role" "eks" {
#   name = "${var.region}-${var.environment}-eks"

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "eks.amazonaws.com"
#       }
#     }
#   ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "eks" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.eks.name
# }

# resource "aws_eks_cluster" "eks" {
#   name     = "${var.region}-${var.environment}-eks"
#   version  = var.cluster_version
#   role_arn = aws_iam_role.eks.arn

#   vpc_config {
#     endpoint_private_access = false
#     endpoint_public_access  = true

#     subnet_ids = var.private_subnet_ids
#   }

#   access_config {
#     authentication_mode                         = "API"
#     bootstrap_cluster_creator_admin_permissions = true
#   }

#   depends_on = [aws_iam_role_policy_attachment.eks]
# }

# resource "aws_iam_role" "nodes" {
#   name = "${var.region}-${var.environment}-eks-nodes"

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       }
#     }
#   ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.nodes.name
# }

# resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.nodes.name
# }

# resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.nodes.name
# }

# resource "aws_eks_node_group" "general" {
#   cluster_name    = aws_eks_cluster.eks.name
#   version         = var.cluster_version
#   node_group_name = "general"
#   node_role_arn   = aws_iam_role.nodes.arn

#   subnet_ids = var.private_subnet_ids

#   capacity_type  = "ON_DEMAND"
#   instance_types = ["t3.large"]

#   scaling_config {
#     desired_size = 1
#     max_size     = 10
#     min_size     = 0
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   labels = {
#     role = "general"
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
#     aws_iam_role_policy_attachment.amazon_eks_cni_policy,
#     aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
#   ]

#   lifecycle {
#     ignore_changes = [scaling_config[0].desired_size]
#   }
# }

# # resource "aws_eks_node_group" "GPU" {
# #   cluster_name    = aws_eks_cluster.eks.name
# #   version         = var.cluster_version
# #   node_group_name = "GPU"
# #   node_role_arn   = aws_iam_role.nodes.arn

# #   subnet_ids = var.private_subnet_ids

# #   capacity_type  = "SPOT"
# #   instance_types = ["g5.4xlarge"]

# #   scaling_config {
# #     desired_size = 1
# #     max_size     = 3
# #     min_size     = 0
# #   }

# #   update_config {
# #     max_unavailable = 1
# #   }

# #   labels = {
# #     role = "GPU"
# #   }

# #   depends_on = [
# #     aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
# #     aws_iam_role_policy_attachment.amazon_eks_cni_policy,
# #     aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
# #   ]

# #   lifecycle {
# #     ignore_changes = [scaling_config[0].desired_size]
# #   }
# # }

# # resource "aws_eks_addon" "metrics_server" {
# #   cluster_name  = aws_eks_cluster.eks.name
# #   addon_name    = "metrics-server"
# #   addon_version = "v0.7.2-eksbuild.1"
# # }

# resource "aws_eks_addon" "pod_identity" {
#   cluster_name  = aws_eks_cluster.eks.name
#   addon_name    = "eks-pod-identity-agent"
#   addon_version = "v1.3.4-eksbuild.1"
# }

# data "aws_iam_policy_document" "aws_lbc" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["pods.eks.amazonaws.com"]
#     }

#     actions = [
#       "sts:AssumeRole",
#       "sts:TagSession"
#     ]
#   }
# }

# resource "aws_iam_role" "aws_lbc" {
#   name               = "${aws_eks_cluster.eks.name}-aws-lbc"
#   assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
# }

# resource "aws_iam_policy" "aws_lbc" {
#   policy = file("${path.module}/policies/AWSLoadBalancerController.json")
#   name   = "AWSLoadBalancerController"
# }

# resource "aws_iam_role_policy_attachment" "aws_lbc" {
#   policy_arn = aws_iam_policy.aws_lbc.arn
#   role       = aws_iam_role.aws_lbc.name
# }

# resource "aws_eks_pod_identity_association" "aws_lbc" {
#   cluster_name    = aws_eks_cluster.eks.name
#   namespace       = "kube-system"
#   service_account = "aws-load-balancer-controller"
#   role_arn        = aws_iam_role.aws_lbc.arn
# }

# data "aws_iam_policy_document" "ebs_csi_driver" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["pods.eks.amazonaws.com"]
#     }

#     actions = [
#       "sts:AssumeRole",
#       "sts:TagSession"
#     ]
#   }
# }

# resource "aws_iam_role" "ebs_csi_driver" {
#   name               = "${aws_eks_cluster.eks.name}-ebs-csi-driver"
#   assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#   role       = aws_iam_role.ebs_csi_driver.name
# }

# resource "aws_iam_policy" "abs_csi_driver_encryption" {
#   name = "${aws_eks_cluster.eks.name}-ebs-csi-driver-encryption"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt",
#           "kms:GenerateDataKeyWithoutPlaintext",
#           "kms:CreateGrant",
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption" {
#   policy_arn = aws_iam_policy.abs_csi_driver_encryption.arn
#   role       = aws_iam_role.ebs_csi_driver.name
# }

# resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
#   cluster_name    = aws_eks_cluster.eks.name
#   namespace       = "kube-system"
#   service_account = "ebs-csi-controller-sa"
#   role_arn        = aws_iam_role.ebs_csi_driver.arn
# }

# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name             = aws_eks_cluster.eks.name
#   addon_name               = "aws-ebs-csi-driver"
#   addon_version            = "v1.39.0-eksbuild.1"
#   service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

# }


# data "tls_certificate" "eks" {
#   url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
# }


# data "aws_iam_policy_document" "secrets_store_csi" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:kube-system:secrets-store-csi-driver"]
#     }

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }
#   }
# }

# resource "aws_iam_role" "secrets_store_csi" {
#   name               = "${aws_eks_cluster.eks.name}-secrets-store-csi"
#   assume_role_policy = data.aws_iam_policy_document.secrets_store_csi.json
# }

# resource "aws_iam_policy" "secrets_store_csi" {
#   name = "${aws_eks_cluster.eks.name}-secrets-store-csi-policy"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "secrets_store_csi" {
#   role       = aws_iam_role.secrets_store_csi.name
#   policy_arn = aws_iam_policy.secrets_store_csi.arn
# }

# output "secrets_store_csi_role_arn" {
#   value = aws_iam_role.secrets_store_csi.arn
# }

# data "aws_iam_policy_document" "external_secrets" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:external-secrets:external-secrets"]
#     }

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }
#   }
# }

# resource "aws_iam_role" "external_secrets" {
#   name               = "${aws_eks_cluster.eks.name}-external-secrets"
#   assume_role_policy = data.aws_iam_policy_document.external_secrets.json
# }

# resource "aws_iam_policy" "external_secrets" {
#   name = "${aws_eks_cluster.eks.name}-external-secrets-policy"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "external_secrets" {
#   role       = aws_iam_role.external_secrets.name
#   policy_arn = aws_iam_policy.external_secrets.arn
# }

# output "external_secrets_role_arn" {
#   value = aws_iam_role.external_secrets.arn
# }







# # # resource "aws_eks_addon" "pod_identity" {
# # #   cluster_name  = aws_eks_cluster.eks.name
# # #   addon_name    = "eks-pod-identity-agent"
# # #   addon_version = "v1.3.4-eksbuild.1"
# # # }


# # data "aws_iam_policy_document" "aws_lbc" {
# #   statement {
# #     effect = "Allow"

# #     principals {
# #       type        = "Service"
# #       identifiers = ["pods.eks.amazonaws.com"]
# #     }

# #     actions = [
# #       "sts:AssumeRole",
# #       "sts:TagSession"
# #     ]
# #   }
# # }

# # resource "aws_iam_role" "aws_lbc" {
# #   name               = "${aws_eks_cluster.eks.name}-aws-lbc"
# #   assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
# # }

# # resource "aws_iam_policy" "aws_lbc" {
# #   policy = file("${path.module}/policies/AWSLoadBalancerController.json")
# #   name   = "AWSLoadBalancerController"
# # }

# # resource "aws_iam_role_policy_attachment" "aws_lbc" {
# #   policy_arn = aws_iam_policy.aws_lbc.arn
# #   role       = aws_iam_role.aws_lbc.name
# # }

# # resource "aws_eks_pod_identity_association" "aws_lbc" {
# #   cluster_name    = aws_eks_cluster.eks.name
# #   namespace       = "kube-system"
# #   service_account = "aws-load-balancer-controller"
# #   role_arn        = aws_iam_role.aws_lbc.arn
# # }



# # data "aws_eks_cluster" "cluster" {
# #   name = aws_eks_cluster.eks.name
# # }

# # data "aws_eks_cluster_auth" "cluster" {
# #   name = aws_eks_cluster.eks.name
# # }

# # data "tls_certificate" "eks" {
# #   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# # }

# # resource "aws_iam_openid_connect_provider" "eks" {
# #   client_id_list  = ["sts.amazonaws.com"]
# #   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
# #   url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# # }
