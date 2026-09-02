module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  # pinned the module version
  version = "6.4.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnet_cidrs

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  enable_nat_gateway = var.enable_nat_gateway

  tags = var.tags
}