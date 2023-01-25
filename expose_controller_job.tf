resource "kubernetes_config_map_v1" "exposecontroller" {
  data = {
    "config.yml" = <<-EOT
      exposer: Ingress
      domain: ${var.domain}
      http: true
      tls-acme: true
      EOT
  }
  metadata {
    name      = "exposecontroller"
    namespace = var.kubernetes_namespace
  }
}

resource "kubernetes_service_account_v1" "cad3_exposecontroller" {
  metadata {
    labels = {
      app = "cad3-exposecontroller"
    }
    name      = "cad3-exposecontroller"
    namespace = var.kubernetes_namespace
  }
}

resource "kubernetes_role_v1" "cad3_exposecontroller" {
  metadata {
    name      = "cad3-exposecontroller"
    namespace = var.kubernetes_namespace
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "patch", "create", "update", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps", "services"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  rule {
    api_groups = ["extensions", "apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }
  rule {
    api_groups = ["", "route.openshift.io"]
    resources  = ["routes", "routes/custom-host"]
    verbs      = ["get", "list", "watch", "patch", "create", "update", "delete"]
  }

}

resource "kubernetes_role_binding_v1" "cad3_exposecontroller" {
  metadata {
    name = "cad3-exposecontroller"
    namespace = var.kubernetes_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cad3-exposecontroller"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cad3-exposecontroller"
    namespace = var.kubernetes_namespace
  }
}

resource "kubernetes_job_v1" "cad3_exposecontroller" {
  depends_on = [
    kubernetes_config_map_v1.exposecontroller,
    kubernetes_role_v1.cad3_exposecontroller,
    kubernetes_role_binding_v1.cad3_exposecontroller,
    kubernetes_service_account_v1.cad3_exposecontroller,

    kubernetes_namespace.cicd,
    helm_release.jenkins,
    helm_release.chartmuseum,
    helm_release.nexus,
    kubernetes_service.nexus-internal,
  ]

  metadata {
    labels = {
      app = "cad3-exposecontroller"
    }
    name      = "cad3-exposecontroller"
    namespace = var.kubernetes_namespace
  }

  spec {
    template {
      metadata {
        annotations = {
          "sidecar.istio.io/inject" = "false"
          "trigger_source"          = helm_release.jenkins.version
        }
        labels = {
          "app" = "cad3-exposecontroller"
        }
        name = "expose-jx"
      }
      spec {
        container {
          image = "ghcr.io/jenkins-x/exposecontroller:2.3.118"
          name  = "exposecontroller"

          args = [
            "--v",
            "4",
          ]
          command = [
            "/exposecontroller",
          ]
          env {
            name = "KUBERNETES_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "80m"
              memory = "128Mi"
            }
          }
        }
        restart_policy       = "Never"
        service_account_name = "cad3-exposecontroller"
      }
    }
  }
}
