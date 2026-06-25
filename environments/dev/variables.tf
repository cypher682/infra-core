variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  description = "Your AWS account ID"
  type        = string
}

variable "github_org" {
  description = "GitHub username or org (e.g. cypher682)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name (e.g. infra-core)"
  type        = string
  default     = "infra-core"
}

variable "db_password" {
  description = "RDS master password — pass via TF_VAR_db_password env var, never in tfvars file"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm SNS notifications"
  type        = string
}
