resource "kubernetes_secret_v1" "nexus_provision_py" {
  metadata  {
    name      = "nexus-provision"
    namespace = var.kubernetes_namespace
  }
  data = {
    "nexus_provision.py" = base64encode(file("${path.module}/scripts/nexus_provision.py"))
  }
}


resource "kubernetes_job_v1" "cad3_nexus_provision" {
  depends_on = [kubernetes_secret_v1.nexus_provision_py, helm_release.nexus]

  metadata {
    labels = {
      "app" = "cad3-nexus-provision"
    }
    name      = "cad3-nexus-provision"
    namespace = var.kubernetes_namespace
  }
  spec {
    backoff_limit = 5
    template {
      metadata {
        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
        labels = {
          "app" = "cad3-nexus-provision"
        }
        name = "nexus-provision"
      }
      spec {
        container {
          image = "python:3-alpine"
          name  = "nexus-provision"
          command = [
            "/bin/sh",
            "-c",
            "pip3 install -qqq requests && python3 /scripts/nexus_provision.py",
          ]
          env {
            name = "KUBERNETES_NAMESPACE"
            value_from  {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name  = "NEXUS_ADMIN_PASSWORD"
            value = var.admin_password
          }
          env {
            name  = "S3_BUCKET_NAME"
            value = var.nexus_s3_bucket
          }
          env {
            name  = "NEXUS_URL"
            value = "http://nexus:80"
          }
          env {
            name  = "GLOBAL_MAVEN_REPO_URL"
            value = var.global_maven_repo_url
          }

          resources  {
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "80m"
              memory = "128Mi"
            }
          }

          volume_mount {
            mount_path = "/scripts"
            name       = "nexus-provision"
          }
        }
        restart_policy     = "Never"
        service_account_name = "default"

        volume {
          name = "nexus-provision"
          secret {
            secret_name = "nexus-provision"
          }
        }
      }
    }
  }
}
