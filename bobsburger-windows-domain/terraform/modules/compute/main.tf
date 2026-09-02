module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  version = "6.4.0"

  name = var.name
  ami = var.ami
  instance_type = var.instance_type
  iam_instance_profile = var.iam_instance_profile
  subnet_id = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids

  key_name      = var.key_name
  root_block_device = var.root_block_device

  tags = var.tags
}