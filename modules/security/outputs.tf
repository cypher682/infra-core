output "config_role_arn" {
  description = "The ARN of the AWS Config IAM role"
  value       = aws_iam_role.config.arn
}
