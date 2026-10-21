locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ===========================================================================
# Networks
# ===========================================================================

# Simulated on-premises datacenter. Its VPN endpoint is a self-managed EC2
# appliance (strongSwan) acting as the customer gateway, so no VGW.
module "vpc_onprem" {
  source = "./modules/vpc"

  providers = {
    aws = aws.onprem
  }

  name               = "${var.project}-onprem"
  vpc_cidr           = var.onprem_vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.onprem_enable_nat_gateway
  enable_vpn_gateway = false

  tags = { Site = "onprem" }
}

# AWS cloud site. Gets a Virtual Private Gateway as the AWS side of the VPN.
module "vpc_cloud" {
  source = "./modules/vpc"

  providers = {
    aws = aws.cloud
  }

  name               = "${var.project}-cloud"
  vpc_cidr           = var.cloud_vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.cloud_enable_nat_gateway
  enable_vpn_gateway = true

  tags = { Site = "cloud" }
}

# Site-to-site VPN: strongSwan appliance on-prem <-> VGW in the cloud VPC
module "vpn" {
  source = "./modules/vpn"

  providers = {
    aws.onprem = aws.onprem
    aws.cloud  = aws.cloud
  }

  name = var.project

  onprem_vpc_id           = module.vpc_onprem.vpc_id
  onprem_vpc_cidr         = module.vpc_onprem.vpc_cidr
  onprem_public_subnet_id = module.vpc_onprem.public_subnet_ids[0]
  onprem_route_table_ids = [
    module.vpc_onprem.public_route_table_id,
    module.vpc_onprem.private_route_table_id,
  ]
  instance_type     = var.vpn_instance_type
  key_name          = var.vpn_key_name
  ssh_allowed_cidrs = var.vpn_ssh_allowed_cidrs

  cloud_vpn_gateway_id = module.vpc_cloud.vpn_gateway_id
  cloud_vpc_cidr       = module.vpc_cloud.vpc_cidr

  tags = { Component = "vpn" }
}

# ---------------------------------------------------------------------------
# Connectivity test VM in a cloud private subnet. It only needs to answer
# ping from on-prem (test from the strongSwan appliance), so no NAT/SSM.
# ---------------------------------------------------------------------------
module "test_vm_cloud" {
  source = "./modules/linux-vm"
  count  = var.enable_test_vms ? 1 : 0

  providers = {
    aws = aws.cloud
  }

  name          = "${var.project}-cloud-test"
  vpc_id        = module.vpc_cloud.vpc_id
  subnet_id     = module.vpc_cloud.private_subnet_ids[0]
  allowed_cidrs = [var.cloud_vpc_cidr, var.onprem_vpc_cidr]

  tags = { Site = "cloud", Component = "test" }
}

# ===========================================================================
# Databases: RDS (cloud, source) --DMS over VPN--> PostgreSQL VM (on-prem, target)
# ===========================================================================
resource "random_password" "source_db" {
  length  = 24
  special = false
}

resource "random_password" "target_db" {
  length  = 24
  special = false
}

# Source: RDS PostgreSQL in the cloud VPC, with logical replication enabled
# so DMS can capture ongoing changes (CDC)
module "db_source" {
  source = "./modules/rds-postgres"

  providers = {
    aws = aws.cloud
  }

  name           = "${var.project}-source"
  vpc_id         = module.vpc_cloud.vpc_id
  subnet_ids     = module.vpc_cloud.private_subnet_ids
  allowed_cidrs  = [var.cloud_vpc_cidr, var.onprem_vpc_cidr]
  engine_version = var.postgres_version
  instance_class = var.source_db_instance_class
  db_name        = var.db_name
  username       = var.db_username
  password       = random_password.source_db.result

  tags = { Site = "cloud", Role = "source" }
}

# Target: self-managed PostgreSQL on a VM in the on-prem datacenter
module "db_target" {
  source = "./modules/postgres-vm"

  providers = {
    aws = aws.onprem
  }

  name             = "${var.project}-target-postgres"
  vpc_id           = module.vpc_onprem.vpc_id
  subnet_id        = module.vpc_onprem.private_subnet_ids[0]
  allowed_cidrs    = [var.onprem_vpc_cidr, var.cloud_vpc_cidr]
  instance_type    = var.target_db_instance_type
  postgres_version = tonumber(var.postgres_version)
  db_name          = var.db_name
  db_user          = var.db_username
  db_password      = random_password.target_db.result

  tags = { Site = "onprem", Role = "target" }

  # Package install needs the NAT route in place
  depends_on = [module.vpc_onprem]
}

# ===========================================================================
# DMS: runs in the cloud VPC next to RDS; reaches the on-prem target over the VPN
# ===========================================================================
module "dms" {
  source = "./modules/dms"

  providers = {
    aws = aws.cloud
  }

  name       = var.project
  vpc_id     = module.vpc_cloud.vpc_id
  subnet_ids = module.vpc_cloud.private_subnet_ids

  create_iam_roles           = var.dms_create_iam_roles
  replication_instance_class = var.dms_instance_class
  engine_version             = var.dms_engine_version

  source_db = {
    server_name   = module.db_source.address
    port          = module.db_source.port
    database_name = module.db_source.db_name
    username      = module.db_source.username
    password      = random_password.source_db.result
  }

  target_db = {
    server_name   = module.db_target.private_ip
    port          = module.db_target.port
    database_name = module.db_target.db_name
    username      = module.db_target.db_user
    password      = random_password.target_db.result
  }

  start_replication_task = var.dms_start_task

  tags = { Site = "cloud", Component = "dms" }
}

# ===========================================================================
# Renames from the original source/target site naming (keeps existing resources)
# ===========================================================================
moved {
  from = module.vpc_source
  to   = module.vpc_onprem
}

moved {
  from = module.vpc_target
  to   = module.vpc_cloud
}

moved {
  from = module.test_vm_target
  to   = module.test_vm_cloud
}
