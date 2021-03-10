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

resource "helm_release" "jenkins" {
  name       = local.jenkins
  chart      = "jenkins"
  repository = "https://charts.helm.sh/stable"
  namespace  = kubernetes_namespace.cicd.id
  version    = var.jenkins_helm_chart_version
  values = [
    templatefile("${path.module}/templates/jenkins.yaml.tmpl", {
      project_prefix = var.project_prefix
      global_fqdn    = var.global_fqdn
      ecr_url        = local.ecr_url
      admin_password = local.admin_password
      jenkins_cpu    = var.jenkins_resources["cpu"]
      jenkins_memory = var.jenkins_resources["memory"]
      namespace      = kubernetes_namespace.cicd.id
      cadmium_repo   = var.cadmium_repo
      aws_region     = local.aws_region
      iamRole        = module.irsa-jenkins.this_iam_role_arn
    })
  ]
  atomic = true
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

module "irsa-jenkins" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.6.0"
  create_role                   = true
  role_name                     = "eks-${local.jenkins}"
  provider_url                  = replace(var.eks_cluster.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.kubernetes_namespace}:${local.jenkins}"]
}
