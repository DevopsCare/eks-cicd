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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_region = data.aws_region.current.name
  git_provider_url = {
    "github"         = "https://github.com"
    "bitbucketcloud" = "https://bitbucket.org"
  }

  ecr_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"

  jenkins     = "jenkins"
  nexus       = "nexus"
  chartmuseum = "chartmuseum"
}

provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = var.kubernetes_ca_certificate

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", var.eks_cluster.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    cluster_ca_certificate = var.kubernetes_ca_certificate

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", var.eks_cluster.cluster_name]
    }
  }
}


resource "kubernetes_namespace" "cicd" {
  metadata {
    name = var.kubernetes_namespace
  }
}

// See https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/
resource "kubernetes_secret" "bitbucket-token" {
  count = var.git_provider == "bitbucketcloud" ? 1 : 0

  metadata {
    name      = "bitbucket-token"
    namespace = kubernetes_namespace.cicd.id

    labels = {
      # so we know what type it is.
      "jenkins.io/credentials-type" = "usernamePassword"
      "jenkins.io/kind"             = "git"
    }

    annotations = {
      # description - can not be a label as spaces are not allowed
      "jenkins.io/credentials-description" = "Bitbucket Organization CI Token"
      "jenkins.io/url"                     = local.git_provider_url[var.git_provider]
    }
  }

  data = {
    username = var.git_username
    password = var.git_api_token
  }
}

resource "kubernetes_secret" "github-usernamePassword" {
  count = var.git_provider == "github" ? 1 : 0

  metadata {
    name      = "github-username-password"
    namespace = kubernetes_namespace.cicd.id

    labels = {
      # so we know what type it is.
      "jenkins.io/credentials-type" = "usernamePassword"
      "jenkins.io/kind"             = "git"
    }

    annotations = {
      # description - can not be a label as spaces are not allowed
      "jenkins.io/credentials-description" = "GitHub Organization CI Username/Pass"
      "jenkins.io/url"                     = local.git_provider_url[var.git_provider]
    }
  }

  data = {
    username = var.git_username
    password = var.git_api_token
  }
}

resource "kubernetes_secret" "cadmium-usernamePassword" {
  count = var.git_provider == "github" ? 1 : 0

  metadata {
    name      = "cadmium"
    namespace = kubernetes_namespace.cicd.id

    labels = {
      # so we know what type it is.
      "jenkins.io/credentials-type" = "usernamePassword"
    }

    annotations = {
      # description - can not be a label as spaces are not allowed
      "jenkins.io/credentials-description" = "Cadmium repo compatibility"
      "jenkins.io/url"                     = local.git_provider_url[var.git_provider]
    }
  }

  data = {
    username = var.git_username
    password = var.git_api_token
  }
}

resource "kubernetes_secret" "github-token" {
  count = var.git_provider == "github" ? 1 : 0

  metadata {
    name      = "github-token"
    namespace = kubernetes_namespace.cicd.id

    labels = {
      # so we know what type it is.
      "jenkins.io/credentials-type" = "secretText"
    }

    annotations = {
      # description - can not be a label as spaces are not allowed
      "jenkins.io/credentials-description" = "GitHub Organization CI Token"
      "jenkins.io/url"                     = local.git_provider_url[var.git_provider]
    }
  }

  data = {
    text = var.git_api_token
  }
}

resource "kubernetes_secret" "jenkins-docker-cfg" {
  metadata {
    name      = "jenkins-docker-cfg"
    namespace = kubernetes_namespace.cicd.id
  }

  data = {
    "config.json" = "{ \"credsStore\": \"ecr-login\" }"
  }
}
