variable "name" {
  description = "Name prefix / identifier for the RDS resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the RDS instance."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group (at least 2 AZs)."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to connect on 5432 (local VPC and the DMS/peer site)."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL major version (also selects the parameter group family)."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database to create."
  type        = string
  default     = "appdb"
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "dbadmin"
}

variable "password" {
  description = "Master password."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
