resource "local_file" "expose_controller_job" {
  content = templatefile("${path.module}/templates/expose_controller_job.yaml.tmpl", {
    domain    = var.domain,
    namespace = var.kubernetes_namespace
  })

  filename = "${path.module}/expose_controller_job.yaml"
}

resource "null_resource" "process_ingresses" {
  triggers = {
    jenkins = helm_release.jenkins.status
  }

  provisioner "local-exec" {
    command = <<EOT
      kubectl delete job -l app=cad3-exposecontroller -n ${var.kubernetes_namespace} --ignore-not-found=true
      kubectl apply -f ${path.module}/expose_controller_job.yaml
EOT

    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  depends_on = [
    local_file.expose_controller_job,
    kubernetes_namespace.cicd,
    helm_release.jenkins,
    helm_release.chartmuseum,
    helm_release.nexus,
    kubernetes_service.nexus-internal,
  ]
}
