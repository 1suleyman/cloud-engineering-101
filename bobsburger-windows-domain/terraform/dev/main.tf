
# VPC

module "my_local_vpc" {
  # The relative source path must start with ./ or ../
  source = "../modules/network"

  # Pass any input variables that the child module expects

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = var.resource_tags
}

# Security Groups

module "dc_sg" {
  source = "../modules/security"

  name        = var.sg_name
  description = var.sg_description
  vpc_id      = module.my_local_vpc.vpc_id

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

}

module "client_sg" {
  source = "../modules/security"

  name        = var.sg_name
  description = var.sg_description
  vpc_id      = module.my_local_vpc.vpc_id

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

}

module "ssm_managed_node_sg" {
  source = "../modules/security"

  name        = var.sg_name
  description = var.sg_description
  vpc_id      = module.my_local_vpc.vpc_id

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

}

module "ssm_endpoint_sg" {
  source = "../modules/security"

  name        = var.sg_name
  description = var.sg_description
  vpc_id      = module.my_local_vpc.vpc_id

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

}

# EC2 Instances

module "dc01" {

}

module "client01" {
  
}


