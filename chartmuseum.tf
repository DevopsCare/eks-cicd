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
}
