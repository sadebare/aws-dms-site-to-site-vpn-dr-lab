data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Public subnets take netnums 0..n-1, private subnets 10..10+n-1
  # e.g. 10.10.0.0/16 -> public 10.10.0.0/24, 10.10.1.0/24 ; private 10.10.10.0/24, 10.10.11.0/24
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i + 10)]

  tags = merge(var.tags, { Module = "vpc" })
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-igw" })
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# NAT gateway (optional, single AZ to keep lab cost down)
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.tags, { Name = "${var.name}-nat-eip" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.tags, { Name = "${var.name}-nat" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Virtual Private Gateway (optional, AWS side of the site-to-site VPN)
# ---------------------------------------------------------------------------
resource "aws_vpn_gateway" "this" {
  count = var.enable_vpn_gateway ? 1 : 0

  vpc_id          = aws_vpc.this.id
  amazon_side_asn = var.vpn_gateway_amazon_side_asn

  tags = merge(local.tags, { Name = "${var.name}-vgw" })
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-private-rt" })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Propagate VPN-learned routes (peer site CIDR) into both route tables
resource "aws_vpn_gateway_route_propagation" "public" {
  count = var.enable_vpn_gateway ? 1 : 0

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = aws_route_table.public.id
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count = var.enable_vpn_gateway ? 1 : 0

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = aws_route_table.private.id
}
