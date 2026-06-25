variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_password" {
  description = "RDS master password — passed in from tfvars (never hardcoded)"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "RDS endpoint — populated after RDS module runs"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
