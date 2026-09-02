module "sg" {
  source = "terraform-aws-modules/security-group/aws"

  # pinned the module version
  version = "6.0.0"

  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

  tags = var.tags
}
