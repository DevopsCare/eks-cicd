locals {
  git_provider_url = {
    "github"         = "https://github.com"
    "bitbucketcloud" = "https://bitbucket.org"
  }
}

provider "kubernetes" {
  version = "~> 1.11.1"

  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_ca_certificate)
  token                  = var.kubernetes_token
  load_config_file       = false
}

provider "helm" {
  version = "~> 1.1.1"

  kubernetes {
    host                   = var.kubernetes_host
    cluster_ca_certificate = base64decode(var.kubernetes_ca_certificate)
    token                  = var.kubernetes_token
    load_config_file       = false
  }
}

resource "kubernetes_namespace" "cicd" {
  metadata {
    name = var.kubernetes_namespace
  }
}

// See https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/
resource "kubernetes_secret" "bitbucket-token" {
  count      = var.git_provider == "bitbucketcloud" ? 1 : 0
  depends_on = [helm_release.jenkins]

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
  count      = var.git_provider == "github" ? 1 : 0
  depends_on = [helm_release.jenkins]

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
  count      = var.git_provider == "github" ? 1 : 0
  depends_on = [helm_release.jenkins]

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
  count      = var.git_provider == "github" ? 1 : 0
  depends_on = [helm_release.jenkins]

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
  depends_on = [helm_release.jenkins]

  metadata {
    name      = "jenkins-docker-cfg"
    namespace = kubernetes_namespace.cicd.id
  }

  data = {
    "config.json" = "{ \"credsStore\": \"ecr-login\" }"
  }
}
