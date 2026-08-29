########################################################################
# modulo addons
# Componentes de cluster instalados via Helm:
#   - metrics-server  (habilita HPA por CPU)
#   - ingress-nginx   (ponto unico de entrada; cria o NLB)
#   - keda            (autoscaling do analytics-service por profundidade de fila SQS)
#   - argocd          (GitOps -- sincroniza fase-3/gitops/)
#
# Os providers helm/kubernetes sao configurados no root (envs/*/providers.tf)
# a partir dos outputs do modulo eks.
########################################################################

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

resource "helm_release" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [file(var.ingress_nginx_values_path)]

  # expoe o controller via NLB da AWS
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
}

resource "helm_release" "keda" {
  count = var.enable_keda ? 1 : 0

  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_chart_version
  namespace        = "keda"
  create_namespace = true
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  values = compact([
    yamlencode({
      configs = {
        cm = {
          # permite que os kustomization.yaml em fase-3/gitops/ referenciem
          # os manifests em fase-2/*/k8s (fora do diretorio do app)
          "kustomize.buildOptions" = "--load-restrictor LoadRestrictionsNone"
        }
        params = {
          "server.insecure" = true # TLS termina no ingress-nginx
        }
      }
      server = {
        ingress = {
          enabled = false # Ingress declarado no gitops/, se necessario
        }
      }
    }),
    var.argocd_extra_values,
  ])
}
