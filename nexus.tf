
/*
*Copyright (c) 2020 Risk Focus Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/


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
  count = var.provision_nexus ? 1 : 0

  content = templatefile("${path.module}/templates/nexus.provision.yaml.tmpl", {
    nexus_provision_py     = base64encode(file("${path.module}/scripts/nexus_provision.py"))
    namespace              = var.kubernetes_namespace
    default_admin_password = var.default_admin_password
    s3_bucket_name         = var.nexus_s3_bucket
    remote_maven_repo_url  = var.remote_maven_repo_url
  })

  filename = "${path.module}/nexus_provision_job.yaml"
}

resource "null_resource" "provision_nexus" {
  count = var.provision_nexus ? 1 : 0

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
