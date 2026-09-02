module "sg_rules" {
  source = "terraform-aws-modules/security-group/aws"

  # pinned the module version
  version = "6.0.0"

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules
}