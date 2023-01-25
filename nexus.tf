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

resource "kubernetes_secret" "jenkins-maven-settings" {
  metadata {
    name      = "jenkins-maven-settings"
    namespace = kubernetes_namespace.cicd.id
  }

  data = {
    "settings.xml" = templatefile("${path.module}/templates/settings.xml.tmpl", {
      project_prefix = var.project_prefix,
      admin_password = local.admin_password
    })
  }
}

resource "helm_release" "nexus" {
  name       = local.nexus
  chart      = "sonatype-nexus"
  repository = "https://oteemo.github.io/charts/"
  version    = var.nexus_helm_chart_version
  namespace  = kubernetes_namespace.cicd.id
  values = [
    templatefile("${path.module}/templates/nexus.yaml.tmpl", {
      storage_size       = var.nexus_storage_size
      project_prefix     = var.project_prefix
      global_fqdn        = var.global_fqdn
      namespace          = kubernetes_namespace.cicd.id
      set_admin_password = var.provision_nexus ? "false" : "true"
      admin_password     = local.admin_password
      iam_role           = module.irsa-nexus.this_iam_role_arn
    })
  ]
  atomic = true
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

module "irsa-nexus" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.6.0"
  create_role                   = true
  role_name                     = "eks-${local.nexus}"
  provider_url                  = replace(var.eks_cluster.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [module.iam_policy_from_data_source.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.kubernetes_namespace}:${local.nexus}"]
}

module "iam_policy_from_data_source" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "3.6.0"
  name    = "eks-nexus"
  policy  = data.aws_iam_policy_document.nexus.json
}

data "aws_iam_policy_document" "nexus" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutObjectTagging",
      "s3:GetObjectTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteBucket",
      "s3:CreateBucket",
      "s3:GetBucketAcl",
    ]

    resources = [
      "arn:aws:s3:::${var.nexus_s3_bucket}",
      "arn:aws:s3:::${var.nexus_s3_bucket}/*",
    ]
  }
}
