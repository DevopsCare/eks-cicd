resource "helm_release" "jenkins" {
  name       = "jenkins"
  chart      = "jenkins"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  namespace  = kubernetes_namespace.cicd.id
  version    = var.jenkins_helm_chart_version
  values = [
    templatefile("${path.module}/templates/jenkins.yaml.tmpl", {
      project_prefix = var.project_prefix
      global_fqdn    = var.global_fqdn
      ecr_url        = var.ecr_url
      admin_password = var.default_admin_password
      jenkins_cpu    = var.jenkins_resources["cpu"]
      jenkins_memory = var.jenkins_resources["memory"]
      namespace      = kubernetes_namespace.cicd.id
      cadmium_repo   = var.cadmium_repo
    })
  ]
  atomic = true

  lifecycle {
    ignore_changes = [keyring]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_cluster_admin" {
  metadata {
    name = "jenkins-cluster-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.cicd.id
  }
}
