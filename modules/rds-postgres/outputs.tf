output "address" {
  description = "RDS endpoint hostname (DMS source endpoint server name)."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master username."
  value       = aws_db_instance.this.username
}

output "instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = aws_security_group.this.id
}
