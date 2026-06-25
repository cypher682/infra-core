output "db_password_arn" {
  description = "ARN of the DB password SSM parameter"
  value       = aws_ssm_parameter.db_password.arn
}

output "db_host_parameter_name" {
  description = "SSM parameter name for DB host — used in app config"
  value       = aws_ssm_parameter.db_host.name
}

output "parameter_namespace" {
  description = "SSM namespace prefix for this environment"
  value       = "/${var.project}/${var.environment}"
}
