
vpc_name = "bobs-burgers-dev-vpc"
vpc_cidr = "172.16.0.0/16"
availability_zones = [ "eu-west-2a" ]
private_subnet_cidrs = [ "172.16.1.0/24" ]
resource_tags = {
  Environment = "dev"
  Terraform   = "true"
  Project     = "bobs-burgers-windows-domain"
}