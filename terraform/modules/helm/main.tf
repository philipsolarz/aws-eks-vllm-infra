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
