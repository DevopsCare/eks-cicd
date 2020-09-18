/*
* Copyright (c) 2020 Risk Focus Inc.
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
