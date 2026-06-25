output "app_bucket_id" {
  description = "App assets bucket name"
  value       = aws_s3_bucket.app.id
}

output "app_bucket_arn" {
  description = "App assets bucket ARN — passed to IAM module for EC2 instance profile"
  value       = aws_s3_bucket.app.arn
}

output "flow_logs_bucket_id" {
  description = "Flow logs bucket name"
  value       = aws_s3_bucket.flow_logs.id
}

output "flow_logs_bucket_arn" {
  description = "Flow logs bucket ARN — passed to VPC module for flow log destination"
  value       = aws_s3_bucket.flow_logs.arn
}
