output "vpn_connection_id" {
  description = "ID of the Site-to-Site VPN connection."
  value       = aws_vpn_connection.this.id
}

output "customer_gateway_id" {
  description = "ID of the Customer Gateway."
  value       = aws_customer_gateway.this.id
}

output "strongswan_instance_id" {
  description = "Instance ID of the strongSwan appliance (connect with SSM Session Manager)."
  value       = aws_instance.strongswan.id
}

output "strongswan_public_ip" {
  description = "Elastic IP of the strongSwan appliance (Customer Gateway address)."
  value       = aws_eip.strongswan.public_ip
}

output "strongswan_private_ip" {
  description = "Private IP of the strongSwan appliance."
  value       = aws_network_interface.strongswan.private_ip
}

output "tunnel_addresses" {
  description = "AWS-side outside IPs of the two tunnels."
  value = {
    tunnel1 = aws_vpn_connection.this.tunnel1_address
    tunnel2 = aws_vpn_connection.this.tunnel2_address
  }
}

output "tunnel_preshared_keys" {
  description = "Pre-shared keys for the two tunnels."
  value = {
    tunnel1 = aws_vpn_connection.this.tunnel1_preshared_key
    tunnel2 = aws_vpn_connection.this.tunnel2_preshared_key
  }
  sensitive = true
}
