output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability zones used."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway (null if disabled)."
  value       = try(aws_nat_gateway.this[0].id, null)
}

output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway (null if disabled)."
  value       = try(aws_vpn_gateway.this[0].id, null)
}
