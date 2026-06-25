variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the RDS subnet group (minimum 2 for multi-AZ)"
  type        = list(string)
}

variable "sg_rds_id" {
  description = "Security group ID for RDS — only allows app server traffic"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master DB username — sourced from SSM, not hardcoded"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master DB password — sourced from SSM, not hardcoded"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro is free-tier eligible and cheapest option"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB. 20 is minimum and cheapest"
  type        = number
  default     = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
