variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "asg_name" {
  description = "ASG name — used for CPU alarms"
  type        = string
}

variable "db_identifier" {
  description = "RDS instance identifier — used for DB connection alarms"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (from ALB ARN) — used for request count alarms"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix — used for 5XX alarms"
  type        = string
}

variable "scale_up_policy_arn" {
  description = "ASG scale-up policy ARN"
  type        = string
}

variable "scale_down_policy_arn" {
  description = "ASG scale-down policy ARN"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
