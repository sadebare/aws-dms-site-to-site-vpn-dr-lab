variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

# ---------------------------------------------------------------------------
# On-prem site (simulated datacenter, strongSwan appliance)
# ---------------------------------------------------------------------------
variable "onprem_vpc_id" {
  description = "ID of the on-prem VPC where the strongSwan appliance runs."
  type        = string
}

variable "onprem_vpc_cidr" {
  description = "CIDR of the on-prem VPC (advertised to AWS as a static VPN route)."
  type        = string
}

variable "onprem_public_subnet_id" {
  description = "Public subnet in the on-prem VPC for the strongSwan appliance."
  type        = string
}

variable "onprem_route_table_ids" {
  description = "On-prem VPC route tables that should route cloud_vpc_cidr through the strongSwan appliance."
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the strongSwan appliance."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair for SSH. SSM Session Manager is enabled regardless."
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH to the strongSwan appliance. Empty disables SSH ingress."
  type        = list(string)
  default     = []
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN of the customer gateway (required by AWS even with static routing)."
  type        = number
  default     = 65000
}

# ---------------------------------------------------------------------------
# Cloud site (AWS side, Virtual Private Gateway)
# ---------------------------------------------------------------------------
variable "cloud_vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway attached to the cloud VPC."
  type        = string
}

variable "cloud_vpc_cidr" {
  description = "CIDR of the cloud VPC, routed from on-prem through the tunnels."
  type        = string
}

variable "tunnel1_inside_cidr" {
  description = "/30 inside CIDR for tunnel 1 (must be within 169.254.0.0/16)."
  type        = string
  default     = "169.254.10.0/30"
}

variable "tunnel2_inside_cidr" {
  description = "/30 inside CIDR for tunnel 2 (must be within 169.254.0.0/16)."
  type        = string
  default     = "169.254.11.0/30"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
