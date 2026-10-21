# Simulated on-premises datacenter (strongSwan VPN appliance + target PostgreSQL VM)
provider "aws" {
  alias  = "onprem"
  region = var.onprem_region

  default_tags {
    tags = local.common_tags
  }
}

# AWS cloud site (VGW, source RDS PostgreSQL, DMS)
provider "aws" {
  alias  = "cloud"
  region = var.cloud_region

  default_tags {
    tags = local.common_tags
  }
}
