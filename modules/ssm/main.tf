# ─────────────────────────────────────────────
# SSM Parameter Store
# All app secrets live here — EC2 reads at runtime
# Never stored in Terraform state as plaintext (SecureString uses KMS)
# Namespace: /{project}/{environment}/{key}
# ─────────────────────────────────────────────

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project}/${var.environment}/db_password"
  description = "RDS master password"
  type        = "SecureString" # Encrypted with AWS managed KMS key — no extra cost
  value       = var.db_password

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-password"
  })

  lifecycle {
    ignore_changes = [value] # Prevent Terraform from overwriting manual rotations
  }
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project}/${var.environment}/db_username"
  description = "RDS master username"
  type        = "SecureString"
  value       = var.db_username

  tags = var.tags
}

resource "aws_ssm_parameter" "db_host" {
  name        = "/${var.project}/${var.environment}/db_host"
  description = "RDS endpoint hostname"
  type        = "String"
  value       = var.db_host == "" ? "placeholder-update-after-rds-apply" : var.db_host

  tags = var.tags
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/${var.project}/${var.environment}/db_name"
  description = "Database name"
  type        = "String"
  value       = var.db_name

  tags = var.tags
}

resource "aws_ssm_parameter" "environment" {
  name        = "/${var.project}/${var.environment}/app_environment"
  description = "Application environment identifier"
  type        = "String"
  value       = var.environment

  tags = var.tags
}
