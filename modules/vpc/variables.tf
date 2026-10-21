variable "name" {
  description = "Name prefix applied to all resources in this VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must not overlap with the peer site (required for site-to-site VPN routing)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across. DMS subnet groups require at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count must be between 1 and 4."
  }
}

variable "subnet_newbits" {
  description = "Bits added to vpc_cidr to size each subnet (e.g. /16 + 8 = /24)."
  type        = number
  default     = 8
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway so private subnets can reach the internet (package installs, etc.). Incurs hourly cost."
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Create a Virtual Private Gateway attached to this VPC, with route propagation into all route tables. Use on the AWS side of the site-to-site VPN."
  type        = bool
  default     = false
}

variable "vpn_gateway_amazon_side_asn" {
  description = "Amazon-side BGP ASN for the Virtual Private Gateway."
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
