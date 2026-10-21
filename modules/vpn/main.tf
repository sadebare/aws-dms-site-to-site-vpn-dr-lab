locals {
  tags = merge(var.tags, { Module = "vpn" })

  # IKE/IPsec parameters pinned on both ends so negotiation is deterministic.
  # Must stay in sync with the ike=/esp= proposals in templates/strongswan-userdata.sh.tftpl
  ike_versions          = ["ikev2"]
  encryption_algorithms = ["AES256"]
  integrity_algorithms  = ["SHA2-256"]
  dh_group_numbers      = [14]
}

# ===========================================================================
# On-prem site: public IP for the strongSwan appliance
# ===========================================================================
resource "aws_security_group" "strongswan" {
  provider = aws.onprem

  name_prefix = "${var.name}-strongswan-"
  description = "strongSwan VPN appliance"
  vpc_id      = var.onprem_vpc_id

  tags = merge(local.tags, { Name = "${var.name}-strongswan-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Traffic from on-prem hosts that the appliance forwards into the tunnels
resource "aws_vpc_security_group_ingress_rule" "from_onprem_vpc" {
  provider = aws.onprem

  security_group_id = aws_security_group.strongswan.id
  description       = "Traffic from on-prem VPC to be routed over the VPN"
  cidr_ipv4         = var.onprem_vpc_cidr
  ip_protocol       = "-1"
}

# Traffic from the cloud VPC arriving over the tunnels
resource "aws_vpc_security_group_ingress_rule" "from_cloud_vpc" {
  provider = aws.onprem

  security_group_id = aws_security_group.strongswan.id
  description       = "Traffic from cloud VPC arriving over the VPN"
  cidr_ipv4         = var.cloud_vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ike" {
  provider = aws.onprem
  for_each = {
    tunnel1 = aws_vpn_connection.this.tunnel1_address
    tunnel2 = aws_vpn_connection.this.tunnel2_address
  }

  security_group_id = aws_security_group.strongswan.id
  description       = "IKE from AWS ${each.key}"
  cidr_ipv4         = "${each.value}/32"
  ip_protocol       = "udp"
  from_port         = 500
  to_port           = 500
}

resource "aws_vpc_security_group_ingress_rule" "nat_t" {
  provider = aws.onprem
  for_each = {
    tunnel1 = aws_vpn_connection.this.tunnel1_address
    tunnel2 = aws_vpn_connection.this.tunnel2_address
  }

  security_group_id = aws_security_group.strongswan.id
  description       = "IPsec NAT-T from AWS ${each.key}"
  cidr_ipv4         = "${each.value}/32"
  ip_protocol       = "udp"
  from_port         = 4500
  to_port           = 4500
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  provider = aws.onprem
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = aws_security_group.strongswan.id
  description       = "SSH"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  provider = aws.onprem

  security_group_id = aws_security_group.strongswan.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ENI is created up front so the EIP is already associated when the instance
# boots, and strongSwan initiates IKE from the address AWS expects.
resource "aws_network_interface" "strongswan" {
  provider = aws.onprem

  subnet_id         = var.onprem_public_subnet_id
  security_groups   = [aws_security_group.strongswan.id]
  source_dest_check = false # required to route traffic for other hosts

  tags = merge(local.tags, { Name = "${var.name}-strongswan-eni" })
}

resource "aws_eip" "strongswan" {
  provider = aws.onprem

  domain            = "vpc"
  network_interface = aws_network_interface.strongswan.id

  tags = merge(local.tags, { Name = "${var.name}-strongswan-eip" })
}

# ===========================================================================
# Cloud site: Customer Gateway + VPN connection on the VGW
# ===========================================================================
resource "aws_customer_gateway" "this" {
  provider = aws.cloud

  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = aws_eip.strongswan.public_ip
  type       = "ipsec.1"

  tags = merge(local.tags, { Name = "${var.name}-cgw" })
}

resource "aws_vpn_connection" "this" {
  provider = aws.cloud

  vpn_gateway_id      = var.cloud_vpn_gateway_id
  customer_gateway_id = aws_customer_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_inside_cidr                  = var.tunnel1_inside_cidr
  tunnel1_ike_versions                 = local.ike_versions
  tunnel1_phase1_encryption_algorithms = local.encryption_algorithms
  tunnel1_phase1_integrity_algorithms  = local.integrity_algorithms
  tunnel1_phase1_dh_group_numbers      = local.dh_group_numbers
  tunnel1_phase2_encryption_algorithms = local.encryption_algorithms
  tunnel1_phase2_integrity_algorithms  = local.integrity_algorithms
  tunnel1_phase2_dh_group_numbers      = local.dh_group_numbers

  tunnel2_inside_cidr                  = var.tunnel2_inside_cidr
  tunnel2_ike_versions                 = local.ike_versions
  tunnel2_phase1_encryption_algorithms = local.encryption_algorithms
  tunnel2_phase1_integrity_algorithms  = local.integrity_algorithms
  tunnel2_phase1_dh_group_numbers      = local.dh_group_numbers
  tunnel2_phase2_encryption_algorithms = local.encryption_algorithms
  tunnel2_phase2_integrity_algorithms  = local.integrity_algorithms
  tunnel2_phase2_dh_group_numbers      = local.dh_group_numbers

  tags = merge(local.tags, { Name = "${var.name}-vpn" })
}

# Tells the VGW that the on-prem CIDR lives behind this VPN; propagated into
# the cloud route tables by the VGW route propagation in the vpc module.
resource "aws_vpn_connection_route" "onprem_vpc" {
  provider = aws.cloud

  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = var.onprem_vpc_cidr
}

# ===========================================================================
# On-prem site: strongSwan appliance
# ===========================================================================
data "aws_ami" "ubuntu" {
  provider = aws.onprem

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "strongswan" {
  provider = aws.onprem

  name_prefix = "${var.name}-strongswan-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  provider = aws.onprem

  role       = aws_iam_role.strongswan.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "strongswan" {
  provider = aws.onprem

  name_prefix = "${var.name}-strongswan-"
  role        = aws_iam_role.strongswan.name
}

resource "aws_instance" "strongswan" {
  provider = aws.onprem

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.strongswan.name

  network_interface {
    network_interface_id = aws_network_interface.strongswan.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/templates/strongswan-userdata.sh.tftpl", {
    public_ip          = aws_eip.strongswan.public_ip
    cloud_vpc_cidr     = var.cloud_vpc_cidr
    tunnel1_address    = aws_vpn_connection.this.tunnel1_address
    tunnel1_psk        = aws_vpn_connection.this.tunnel1_preshared_key
    tunnel1_cgw_inside = aws_vpn_connection.this.tunnel1_cgw_inside_address
    tunnel1_vgw_inside = aws_vpn_connection.this.tunnel1_vgw_inside_address
    tunnel2_address    = aws_vpn_connection.this.tunnel2_address
    tunnel2_psk        = aws_vpn_connection.this.tunnel2_preshared_key
    tunnel2_cgw_inside = aws_vpn_connection.this.tunnel2_cgw_inside_address
    tunnel2_vgw_inside = aws_vpn_connection.this.tunnel2_vgw_inside_address
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = merge(local.tags, { Name = "${var.name}-strongswan" })

  lifecycle {
    # A newer Ubuntu AMI must not rebuild the VPN appliance
    ignore_changes = [ami]
  }
}

# Send traffic for the cloud VPC to the strongSwan appliance
resource "aws_route" "to_cloud" {
  provider = aws.onprem
  count    = length(var.onprem_route_table_ids)

  route_table_id         = var.onprem_route_table_ids[count.index]
  destination_cidr_block = var.cloud_vpc_cidr
  network_interface_id   = aws_network_interface.strongswan.id
}

# ===========================================================================
# Renames from the original source/target site naming (keeps existing resources)
# ===========================================================================
moved {
  from = aws_vpc_security_group_ingress_rule.from_source_vpc
  to   = aws_vpc_security_group_ingress_rule.from_onprem_vpc
}

moved {
  from = aws_vpc_security_group_ingress_rule.from_target_vpc
  to   = aws_vpc_security_group_ingress_rule.from_cloud_vpc
}

moved {
  from = aws_vpn_connection_route.source_vpc
  to   = aws_vpn_connection_route.onprem_vpc
}

moved {
  from = aws_route.to_target
  to   = aws_route.to_cloud
}
