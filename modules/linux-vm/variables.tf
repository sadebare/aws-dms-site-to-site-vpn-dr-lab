variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch the instance in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance in."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the instance on all protocols (local VPC and peer site)."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 8
}

variable "key_name" {
  description = "Optional EC2 key pair. SSM Session Manager is enabled regardless."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Optional cloud-init / shell user data."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
