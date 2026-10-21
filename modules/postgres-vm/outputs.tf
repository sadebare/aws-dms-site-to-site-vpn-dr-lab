output "instance_id" {
  description = "Instance ID (connect with SSM Session Manager)."
  value       = module.vm.instance_id
}

output "private_ip" {
  description = "Private IP of the database VM (DMS endpoint server name)."
  value       = module.vm.private_ip
}

output "port" {
  description = "PostgreSQL port."
  value       = 5432
}

output "db_name" {
  description = "Application database name."
  value       = var.db_name
}

output "db_user" {
  description = "Database user."
  value       = var.db_user
}

output "security_group_id" {
  description = "Security group attached to the database VM."
  value       = module.vm.security_group_id
}
