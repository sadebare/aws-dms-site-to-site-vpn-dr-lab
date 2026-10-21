locals {
  tags = merge(var.tags, { Module = "rds-postgres" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, { Name = "${var.name}-subnets" })
}

# ---------------------------------------------------------------------------
# Security group: PostgreSQL from allowed CIDRs only
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-rds-"
  description = "${var.name} RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-rds-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "PostgreSQL from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

# ---------------------------------------------------------------------------
# Parameter group: logical replication for DMS change data capture (CDC)
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg${var.engine_version}-"
  family      = "postgres${var.engine_version}"
  description = "${var.name} PostgreSQL with logical replication for DMS"

  # Sets wal_level = logical; static parameter, applied at instance creation/reboot
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Recommended by DMS so idle replication connections are not dropped
  parameter {
    name  = "wal_sender_timeout"
    value = "0"
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# RDS instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1

  # Lab settings: easy teardown
  apply_immediately   = true
  deletion_protection = false
  skip_final_snapshot = true

  tags = merge(local.tags, { Name = "${var.name}-postgres" })
}
