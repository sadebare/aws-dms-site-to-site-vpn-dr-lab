output "onprem_vpc" {
  description = "Simulated on-prem VPC details."
  value = {
    region             = var.onprem_region
    vpc_id             = module.vpc_onprem.vpc_id
    vpc_cidr           = module.vpc_onprem.vpc_cidr
    public_subnet_ids  = module.vpc_onprem.public_subnet_ids
    private_subnet_ids = module.vpc_onprem.private_subnet_ids
  }
}

output "cloud_vpc" {
  description = "Cloud VPC details."
  value = {
    region             = var.cloud_region
    vpc_id             = module.vpc_cloud.vpc_id
    vpc_cidr           = module.vpc_cloud.vpc_cidr
    public_subnet_ids  = module.vpc_cloud.public_subnet_ids
    private_subnet_ids = module.vpc_cloud.private_subnet_ids
    vpn_gateway_id     = module.vpc_cloud.vpn_gateway_id
  }
}

output "vpn" {
  description = "Site-to-site VPN details."
  value = {
    vpn_connection_id      = module.vpn.vpn_connection_id
    customer_gateway_id    = module.vpn.customer_gateway_id
    strongswan_instance_id = module.vpn.strongswan_instance_id
    strongswan_public_ip   = module.vpn.strongswan_public_ip
    strongswan_private_ip  = module.vpn.strongswan_private_ip
    tunnel_addresses       = module.vpn.tunnel_addresses
  }
}

output "databases" {
  description = "Source (RDS, cloud) and target (VM, on-prem) PostgreSQL connection details."
  value = {
    source = {
      site     = "cloud"
      region   = var.cloud_region
      host     = module.db_source.address
      port     = module.db_source.port
      db_name  = module.db_source.db_name
      username = module.db_source.username
    }
    target = {
      site        = "onprem"
      region      = var.onprem_region
      instance_id = module.db_target.instance_id
      host        = module.db_target.private_ip
      port        = module.db_target.port
      db_name     = module.db_target.db_name
      username    = module.db_target.db_user
    }
  }
}

output "db_passwords" {
  description = "Database passwords. Show with: terraform output -json db_passwords"
  value = {
    source = random_password.source_db.result
    target = random_password.target_db.result
  }
  sensitive = true
}

output "dms" {
  description = "DMS replication instance, endpoints and task."
  value = {
    replication_instance_arn = module.dms.replication_instance_arn
    replication_instance_ips = module.dms.replication_instance_private_ips
    source_endpoint_arn      = module.dms.source_endpoint_arn
    target_endpoint_arn      = module.dms.target_endpoint_arn
    replication_task_arn     = module.dms.replication_task_arn
    replication_task_id      = module.dms.replication_task_id
  }
}

output "test_vm_cloud" {
  description = "Connectivity test VM in the cloud VPC. Ping it from the strongSwan appliance."
  value = var.enable_test_vms ? {
    region      = var.cloud_region
    instance_id = module.test_vm_cloud[0].instance_id
    private_ip  = module.test_vm_cloud[0].private_ip
    test        = "ping -I ${module.vpn.strongswan_private_ip} -c 3 ${module.test_vm_cloud[0].private_ip}"
  } : null
}
