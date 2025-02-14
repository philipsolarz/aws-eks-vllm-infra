resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "kubernetes_service_account" "external_secrets" {
  depends_on = [kubernetes_namespace.external_secrets]

  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
    }
  }
}

resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.karpenter_role_arn
    }
  }
}

resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  chart            = "${path.module}/../../../k8s/modules/argo-cd"
  namespace        = "argo-cd"
  create_namespace = true

}

resource "helm_release" "app_of_apps" {
  name  = "app-of-apps"
  chart = "${path.module}/../../../k8s/"

  depends_on = [helm_release.argo-cd]
}

# resource "helm_release" "argo-cd" {
#   name = "argo-cd"

#   # repository = "https://kubernetes-sigs.github.io/metrics-server"
#   # chart      = "metrics-server"

#   chart     = "../../k8s/modules/argo-cd"
#   namespace = "argo-cd"
#   # version    = "3.12.2"

#   # values = [file("${path.module}/../../k8s/modules/argo-cd/values.yaml")]
# }


# terraform {
#   required_providers {
#     helm = {
#       source  = "hashicorp/helm"
#       version = "3.0.0-pre1"
#     }
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "2.35.1"
#     }
#   }
# } 

# resource "helm_release" "argo-cd" {
#   name             = "argo-cd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   version          = "7.7.16"
#   namespace        = "argo-cd"
#   create_namespace = true

# }

# resource "helm_release" "app_of_apps" {
#   name  = "app-of-apps"
#   chart = "${path.module}/../../../k8s/"

#   depends_on = [helm_release.argo-cd]
# }
