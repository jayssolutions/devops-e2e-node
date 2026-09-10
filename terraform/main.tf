module "network" {
  source       = "./modules/network"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "compute" {
  source             = "./modules/compute"
  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  alb_security_group = module.alb.alb_security_group_id
  target_group_arn   = module.alb.target_group_arn
  instance_type      = var.instance_type
  instance_count     = var.instance_count
  admin_cidr         = var.admin_cidr
  public_key         = var.public_key
}
