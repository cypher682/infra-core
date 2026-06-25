variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (must be in 2+ AZs)"
  type        = list(string)
}

variable "sg_alb_id" {
  description = "Security group for the ALB"
  type        = string
}

variable "health_check_path" {
  description = "Health check path on the target EC2 instances"
  type        = string
  default     = "/health"
}

variable "target_port" {
  description = "Port the app server listens on"
  type        = number
  default     = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
