output "instance_id" {
  description = "Instance ID (connect with SSM Session Manager)."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of the instance."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security group attached to the instance."
  value       = aws_security_group.this.id
}
