variable "project" {
  description = "Project name, used as a prefix for resource names."
  type        = string
  default     = "dr-db-repl"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "lab"
}

# ---------------------------------------------------------------------------
# Sites
# ---------------------------------------------------------------------------
variable "onprem_region" {
  description = "Region for the simulated on-premises site (replication target)."
  type        = string
  default     = "us-east-1"
}

variable "cloud_region" {
  description = "Region for the AWS cloud site (RDS replication source and DMS)."
  type        = string
  default     = "us-west-2"
}

variable "onprem_vpc_cidr" {
  description = "CIDR for the on-prem VPC. Must not overlap with cloud_vpc_cidr."
  type        = string
  default     = "10.10.0.0/16"
}

variable "cloud_vpc_cidr" {
  description = "CIDR for the cloud VPC. Must not overlap with onprem_vpc_cidr."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs per VPC (RDS and DMS subnet groups need at least 2)."
  type        = number
  default     = 2
}

variable "onprem_enable_nat_gateway" {
  description = "Create a NAT gateway in the on-prem VPC (needed for the target DB VM to install PostgreSQL)."
  type        = bool
  default     = true
}

variable "cloud_enable_nat_gateway" {
  description = "Create a NAT gateway in the cloud VPC (not needed: RDS and DMS install nothing)."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# VPN
# ---------------------------------------------------------------------------
variable "vpn_instance_type" {
  description = "Instance type for the strongSwan VPN appliance."
  type        = string
  default     = "t3.micro"
}

variable "vpn_key_name" {
  description = "Optional EC2 key pair for SSH to the VPN appliance (SSM works without it)."
  type        = string
  default     = null
}

variable "vpn_ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH to the VPN appliance, e.g. [\"203.0.113.10/32\"]."
  type        = list(string)
  default     = []
}

variable "enable_test_vms" {
  description = "Launch a small test VM in a cloud private subnet for VPN connectivity tests."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Databases
# ---------------------------------------------------------------------------
variable "postgres_version" {
  description = "PostgreSQL major version for both source (RDS) and target (VM)."
  type        = string
  default     = "16"
}

variable "db_name" {
  description = "Database name on both source and target."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database admin user on both source and target."
  type        = string
  default     = "dbadmin"
}

variable "source_db_instance_class" {
  description = "RDS instance class for the source database (cloud)."
  type        = string
  default     = "db.t4g.micro"
}

variable "target_db_instance_type" {
  description = "EC2 instance type for the target database VM (on-prem)."
  type        = string
  default     = "t3.micro"
}

# ---------------------------------------------------------------------------
# DMS
# ---------------------------------------------------------------------------
variable "dms_create_iam_roles" {
  description = "Create dms-vpc-role and dms-cloudwatch-logs-role (account-wide). Set false if they already exist."
  type        = bool
  default     = true
}

variable "dms_instance_class" {
  description = "DMS replication instance class (dms.t3.micro is not offered in every region)."
  type        = string
  default     = "dms.t3.small"
}

variable "dms_engine_version" {
  description = "DMS engine version. null uses the AWS default."
  type        = string
  default     = null
}

variable "dms_start_task" {
  description = "Start the replication task on apply. Keep false until both endpoint connection tests pass."
  type        = bool
  default     = false
}
