output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — add to GitHub Actions secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name — referenced in launch template"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_instance_profile_arn" {
  description = "EC2 instance profile ARN"
  value       = aws_iam_instance_profile.ec2.arn
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
