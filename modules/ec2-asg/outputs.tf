output "asg_name" {
  description = "Auto Scaling Group name — referenced in CloudWatch alarms"
  value       = aws_autoscaling_group.app.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.app.id
}



output "scale_up_policy_arn" {
  description = "Scale-up policy ARN — attached to CloudWatch CPU alarm"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "Scale-down policy ARN — attached to CloudWatch CPU alarm"
  value       = aws_autoscaling_policy.scale_down.arn
}
