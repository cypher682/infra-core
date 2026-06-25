output "sns_topic_arn" {
  description = "SNS alerts topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "log_group_app" {
  description = "App log group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "cloudwatch_agent_config_parameter" {
  description = "SSM parameter name for CloudWatch agent config"
  value       = aws_ssm_parameter.cloudwatch_agent_config.name
}
