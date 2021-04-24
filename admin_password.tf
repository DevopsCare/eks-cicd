locals {
  admin_password = length(var.admin_password) > 0 ? var.admin_password : random_password.admin_password.result
}

resource "random_password" "admin_password" {
  length      = 16
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  special     = false
}

variable "admin_password" {
  type        = string
  default     = ""
  description = "Will autogenerate random if not set"
}
