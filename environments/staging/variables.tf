variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type    = string
  default = "infra-core"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  type = string
}
