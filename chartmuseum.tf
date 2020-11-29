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

resource "kubernetes_secret" "chartmuseum_secret" {
  metadata {
    name      = "chartmuseum-secret"
    namespace = kubernetes_namespace.cicd.id

    labels = {
      "jenkins.io/credentials-type" = "usernamePassword"
    }

    annotations = {
      "jenkins.io/credentials-description" = "Chartmuseum BasicAuth"
    }
  }

  data = {
    username = "admin"
    password = var.default_admin_password
  }
}


resource "helm_release" "chartmuseum" {
  name       = local.chartmuseum
  chart      = "chartmuseum"
  repository = "https://charts.helm.sh/stable"
  version    = var.chartmuseum_helm_chart_version
  namespace  = kubernetes_namespace.cicd.id
  values = [
    templatefile("${path.module}/templates/chartmuseum.yaml.tmpl", {
      storage_size = var.chartmuseum_storage_size
      iamRole      = module.irsa-chartmuseum.this_iam_role_arn
    })
  ]
  atomic = true

  depends_on = [
    kubernetes_secret.chartmuseum_secret
  ]
}

module "irsa-chartmuseum" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.4.0"
  create_role                   = true
  role_name                     = "eks-${local.chartmuseum}"
  provider_url                  = replace(var.eks_cluster.cluster_oidc_issuer_url, "https://", "")
  number_of_role_policy_arns    = 1
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.kubernetes_namespace}:${local.chartmuseum}"]
}
