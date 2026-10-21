locals {
  tags = merge(var.tags, { Module = "dms" })
}

# ===========================================================================
# Account-wide service roles. DMS looks these up by these exact names.
# ===========================================================================
data "aws_iam_policy_document" "dms_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dms_vpc" {
  count = var.create_iam_roles ? 1 : 0

  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  count = var.create_iam_roles ? 1 : 0

  role       = aws_iam_role.dms_vpc[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_cloudwatch_logs" {
  count = var.create_iam_roles ? 1 : 0

  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs" {
  count = var.create_iam_roles ? 1 : 0

  role       = aws_iam_role.dms_cloudwatch_logs[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# New IAM roles take a few seconds to become usable by DMS; without this the
# subnet group creation fails with "dms-vpc-role is not configured properly"
resource "time_sleep" "iam_propagation" {
  create_duration = var.create_iam_roles ? "30s" : "0s"

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs,
  ]
}

# ===========================================================================
# Networking
# ===========================================================================
resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = "${var.name}-dms-subnets"
  replication_subnet_group_description = "${var.name} DMS replication subnets"
  subnet_ids                           = var.subnet_ids

  tags = merge(local.tags, { Name = "${var.name}-dms-subnets" })

  depends_on = [time_sleep.iam_propagation]
}

# DMS only makes outbound connections (to the source RDS and, over the VPN,
# to the on-prem target), so no ingress rules are needed
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-dms-"
  description = "${var.name} DMS replication instance"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-dms-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ===========================================================================
# Replication instance
# ===========================================================================
resource "aws_dms_replication_instance" "this" {
  replication_instance_id    = "${var.name}-dms"
  replication_instance_class = var.replication_instance_class
  engine_version             = var.engine_version
  allocated_storage          = var.allocated_storage

  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = [aws_security_group.this.id]
  publicly_accessible         = false
  multi_az                    = false

  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(local.tags, { Name = "${var.name}-dms" })
}

# ===========================================================================
# Endpoints
# ===========================================================================
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.name}-source-rds"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = var.source_db.server_name
  port          = var.source_db.port
  database_name = var.source_db.database_name
  username      = var.source_db.username
  password      = var.source_db.password
  ssl_mode      = var.source_db.ssl_mode

  postgres_settings {
    # Built-in logical decoding plugin, no extension needed on RDS
    plugin_name = "test_decoding"
    # Periodic writes keep the replication slot advancing when the source is
    # idle, so WAL does not pile up on RDS
    heartbeat_enable    = true
    heartbeat_frequency = 5
  }

  tags = merge(local.tags, { Name = "${var.name}-source-rds" })
}

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.name}-target-onprem"
  endpoint_type = "target"
  engine_name   = "postgres"

  server_name   = var.target_db.server_name
  port          = var.target_db.port
  database_name = var.target_db.database_name
  username      = var.target_db.username
  password      = var.target_db.password
  ssl_mode      = var.target_db.ssl_mode

  tags = merge(local.tags, { Name = "${var.name}-target-onprem" })
}

# ===========================================================================
# Replication task
# ===========================================================================
resource "aws_dms_replication_task" "this" {
  replication_task_id      = "${var.name}-rds-to-onprem"
  migration_type           = var.migration_type
  replication_instance_arn = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn
  start_replication_task   = var.start_replication_task

  table_mappings = jsonencode({
    rules = [{
      "rule-type"   = "selection"
      "rule-id"     = "1"
      "rule-name"   = "include-${var.schema_name}"
      "rule-action" = "include"
      "object-locator" = {
        "schema-name" = var.schema_name
        "table-name"  = "%"
      }
    }]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32
    }
    FullLoadSettings = {
      # Target DB is empty; DMS creates the tables (PKs included) on first load
      TargetTablePrepMode = "DROP_AND_CREATE"
    }
    Logging = {
      EnableLogging = true
    }
    # Row-by-row comparison of source and target after the load and during CDC
    ValidationSettings = {
      EnableValidation = true
    }
  })

  tags = merge(local.tags, { Name = "${var.name}-rds-to-onprem" })

  lifecycle {
    # DMS expands the settings JSON with defaults, which otherwise shows as a
    # perpetual diff
    ignore_changes = [replication_task_settings]
  }
}
