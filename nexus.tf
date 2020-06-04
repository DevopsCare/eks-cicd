resource "kubernetes_secret" "jenkins-maven-settings" {
  depends_on = [
    helm_release.jenkins,
    helm_release.nexus
  ]

  metadata {
    name      = "jenkins-maven-settings"
    namespace = kubernetes_namespace.cicd.id
  }

  data = {
    "settings.xml" = templatefile("${path.module}/templates/settings.xml.tmpl", {
      project_prefix = var.project_prefix,
      admin_password = var.default_admin_password
    })
  }
}

resource "helm_release" "nexus" {
  name       = "nexus"
  chart      = "sonatype-nexus"
  repository = "https://oteemo.github.io/charts/"
  version    = var.nexus_helm_chart_version
  namespace  = kubernetes_namespace.cicd.id
  values = [
    templatefile("${path.module}/templates/nexus.yaml.tmpl", {
      storage_size           = var.nexus_storage_size,
      project_prefix         = var.project_prefix,
      global_fqdn            = var.global_fqdn,
      namespace              = kubernetes_namespace.cicd.id,
      default_admin_password = var.default_admin_password
    })
  ]
  atomic = true

  lifecycle {
    ignore_changes = [keyring]
  }
}

resource "kubernetes_service" "nexus-internal" {
  metadata {
    name      = "nexus-internal"
    namespace = helm_release.nexus.namespace
    annotations = {
      "fabric8.io/expose"              = "true"
      "fabric8.io/exposeHostNameAs"    = "external-dns.alpha.kubernetes.io/hostname"
      "fabric8.io/ingress.annotations" = "kubernetes.io/ingress.class: noop\nkubernetes.io/tls-acme: false"
    }
  }
  spec {
    selector = {
      app     = helm_release.nexus.name
      release = helm_release.nexus.name
    }

    port {
      name        = "nexus-http"
      port        = 80
      target_port = 8081
    }

    type       = "ClusterIP"
    cluster_ip = "None"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "local_file" "nexus_provision_job" {
  content = templatefile("${path.module}/templates/nexus.provision.yaml.tmpl", {
    nexus_provision_py     = base64encode(file("${path.module}/scripts/nexus_provision.py"))
    namespace              = var.kubernetes_namespace
    default_admin_password = var.default_admin_password
    s3_bucket_name         = "com.riskfocus.${var.project_prefix}.nexus"
  })

  filename = "${path.module}/nexus_provision_job.yaml"
}

resource "null_resource" "provision_nexus" {
  triggers = {
    jenkins = helm_release.nexus.status
  }

  provisioner "local-exec" {
    command = <<EOT
      kubectl delete job -l app=cad3-nexus-provision -n ${var.kubernetes_namespace} --ignore-not-found=true
      kubectl apply -f ${path.module}/nexus_provision_job.yaml
EOT

    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  depends_on = [
    local_file.nexus_provision_job,
    kubernetes_namespace.cicd,
    helm_release.jenkins,
    helm_release.chartmuseum,
    helm_release.nexus,
  ]
}
