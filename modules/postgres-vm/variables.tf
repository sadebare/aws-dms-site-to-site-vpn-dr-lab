variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch the database VM in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the database VM in (private subnet with NAT for package installs)."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to connect to PostgreSQL (security group and pg_hba.conf)."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GiB (holds the PostgreSQL data directory)."
  type        = number
  default     = 10
}

variable "postgres_version" {
  description = "PostgreSQL major version from the Amazon Linux 2023 repos (15, 16, ...)."
  type        = number
  default     = 16
}

variable "db_name" {
  description = "Database to create (DMS replicates into it)."
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Database user that owns db_name. Also used by the DMS target endpoint."
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Password for db_user."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
