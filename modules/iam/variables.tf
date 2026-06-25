variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username (e.g. cypher682)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. infra-core)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID — used to scope IAM policy resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_arn" {
  description = "ARN of the app S3 bucket — granted to EC2 instance profile"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
