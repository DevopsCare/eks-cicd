resource "helm_release" "nexus" {
  name       = "nexus"
  chart      = "sonatype-nexus"
  repository = "https://oteemo.github.io/charts/"
  version    = var.nexus_helm_chart_version
  namespace  = kubernetes_namespace.cicd.id
  values = [
    templatefile("${path.module}/templates/nexus.yaml.tmpl", {
      storage_size   = var.nexus_storage_size,
      project_prefix = var.project_prefix,
      global_fqdn    = var.global_fqdn,
      namespace      = kubernetes_namespace.cicd.id,
    })
  ]
  atomic = true

  lifecycle {
    ignore_changes = [keyring]
  }
}
