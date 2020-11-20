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
  default = "2.8.0"
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

variable "nexus_s3_bucket" {
  type    = string
  default = "example-nexus-s3-bucket"
}

variable "provision_nexus" {
  type    = bool
  default = false
}

variable "remote_maven_repo_url" {
  type    = string
  default = "http://example.com"
}
