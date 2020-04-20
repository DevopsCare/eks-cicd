variable "default_admin_password" {
  type    = string
  default = "overTheCuckoo"
}

# Jenkins specific
variable "jenkins_resources" {
  type = map(string)
  default = {
    "cpu" : "1",
    "memory" : "2Gi",
  }
}
variable "jenkins_helm_chart_version" {
  type    = string
  default = "1.13.0"
}
#

# Nexus specific
variable "nexus_storage_size" {
  type    = string
  default = "20Gi"
}
variable "nexus_helm_chart_version" {
  type    = string
  default = "2.0.0"
}
#

# Chartmuseum specific
variable "chartmuseum_storage_size" {
  type    = string
  default = "2Gi"
}
variable "chartmuseum_helm_chart_version" {
  type    = string
  default = "2.11.0"
}
#

variable "domain" {
  type = string
}

variable "environment_git_owner" {
  type = string
}

variable "git_provider" {
  type    = string
  default = "github"
}

variable "git_username" {
  type = string
}

variable "git_api_token" {
  type = string

  description = <<EOF
https://bitbucket.org/account/user/USERNAME/app-passwords/new

Access:
* Repo: admin NO-delete
* PR: rw
* issue: r
* Webhooks: rw
EOF

}

variable "kubeconfig_filename" {
}

variable "kubernetes_host" {
}

variable "kubernetes_ca_certificate" {
}

variable "kubernetes_token" {
}

variable "project_prefix" {
}

variable "global_fqdn" {
}

variable "ecr_url" {
  default = ""
}

variable "kubernetes_namespace" {
  type    = string
  default = "cicd"
}

variable "cadmium_repo" {
  type    = string
  default = "none"
}
