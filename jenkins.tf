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

resource "kubernetes_role" "jenkins_ns_management" {
  metadata {
    name      = "jenkins-ns-managemenet"
    namespace = kubernetes_namespace.cicd.id
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "create", "delete", "update"]
  }
}

resource "kubernetes_role_binding" "jenkins_ns_management" {
  metadata {
    name      = "jenkins-ns-managemenet"
    namespace = kubernetes_namespace.cicd.id
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jenkins-ns-managemenet"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.cicd.id
  }
}
