output "db_endpoint" {
  description = "RDS connection endpoint — passed to SSM module as db_host"
  value       = aws_db_instance.main.endpoint
}

output "db_host" {
  description = "RDS hostname only (no port)"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}
