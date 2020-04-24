resource "kubernetes_secret" "chartmuseum_secret" {
  metadata {
    name      = "chartmuseum-secret"
    namespace = kubernetes_namespace.cicd.id
  }

  data = {
    "basic-auth-user" = "admin",
    "basic-auth-pass" = var.default_admin_password
  }
}


resource "helm_release" "chartmuseum" {
  name       = "chartmuseum"
  chart      = "chartmuseum"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  version    = var.chartmuseum_helm_chart_version
  namespace  = kubernetes_namespace.cicd.id
  values = [
    templatefile("${path.module}/templates/chartmuseum.yaml.tmpl", {
      storage_size = var.chartmuseum_storage_size
    })
  ]
  atomic = true

  lifecycle {
    ignore_changes = [keyring]
  }

  depends_on = [
    kubernetes_secret.chartmuseum_secret
  ]
}
