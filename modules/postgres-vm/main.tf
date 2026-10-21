module "vm" {
  source = "../linux-vm"

  name             = var.name
  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id
  allowed_cidrs    = var.allowed_cidrs
  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size

  user_data = templatefile("${path.module}/templates/postgres-userdata.sh.tftpl", {
    postgres_version = var.postgres_version
    db_name          = var.db_name
    db_user          = var.db_user
    db_password      = var.db_password
    allowed_cidrs    = var.allowed_cidrs
  })

  tags = merge(var.tags, { Component = "database" })
}
