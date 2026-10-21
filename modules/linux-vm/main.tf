locals {
  tags = merge(var.tags, { Module = "linux-vm" })
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "${var.name} instance"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "allowed" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "All traffic from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------
# IAM (SSM Session Manager access)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  name_prefix = "${var.name}-"
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
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.this.name
}

# ---------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.this.name

  user_data                   = var.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = merge(local.tags, { Name = var.name })

  lifecycle {
    ignore_changes = [ami] # don't replace the VM every time a new AL2023 AMI is published
  }
}
