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
  description = "Private subnets for ASG EC2 instances"
  type        = list(string)
}


variable "sg_app_id" {
  description = "Security group for app EC2 instances"
  type        = string
}


variable "target_group_arn" {
  description = "ALB target group ARN — ASG registers instances here"
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro = ~$0.0104/hr (cheapest for sprint)"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired number of instances at steady state"
  type        = number
  default     = 1
}

variable "ssm_parameter_namespace" {
  description = "SSM namespace for app secrets (e.g. /infra-core/dev)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
