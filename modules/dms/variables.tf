variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the replication instance (same VPC as the source RDS)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the replication subnet group (at least 2 AZs)."
  type        = list(string)
}

variable "create_iam_roles" {
  description = "Create the account-wide dms-vpc-role and dms-cloudwatch-logs-role. Set false if they already exist."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Replication instance
# ---------------------------------------------------------------------------
variable "replication_instance_class" {
  description = "DMS replication instance class."
  type        = string
  default     = "dms.t3.small"
}

variable "engine_version" {
  description = "DMS engine version. null uses the AWS default."
  type        = string
  default     = null
}

variable "allocated_storage" {
  description = "Replication instance storage in GiB (holds cached changes and logs)."
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
variable "source_db" {
  description = "Source PostgreSQL connection (RDS)."
  type = object({
    server_name   = string
    port          = number
    database_name = string
    username      = string
    password      = string
    ssl_mode      = optional(string, "require") # RDS PostgreSQL 15+ forces SSL by default
  })
  sensitive = true
}

variable "target_db" {
  description = "Target PostgreSQL connection (on-prem VM, reached over the VPN)."
  type = object({
    server_name   = string
    port          = number
    database_name = string
    username      = string
    password      = string
    ssl_mode      = optional(string, "none") # traffic is already encrypted by the IPsec tunnel
  })
  sensitive = true
}

# ---------------------------------------------------------------------------
# Task
# ---------------------------------------------------------------------------
variable "migration_type" {
  description = "full-load, cdc, or full-load-and-cdc."
  type        = string
  default     = "full-load-and-cdc"
}

variable "schema_name" {
  description = "Source schema to replicate."
  type        = string
  default     = "public"
}

variable "start_replication_task" {
  description = "Start the task on apply. Default false: test the endpoints first, then start it."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
