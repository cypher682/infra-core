output "repository_url" {
  description = "The URL of the repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "repository_arn" {
  description = "Full ARN of the repository"
  value       = aws_ecr_repository.app_repo.arn
}

output "repository_name" {
  description = "Name of the repository"
  value       = aws_ecr_repository.app_repo.name
}
