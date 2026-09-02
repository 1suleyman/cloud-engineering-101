output "instance_id" {
  description = "The ID of the instance"
  value       = module.ec2_instance.instance_id
}

output "private_ip" {
  description = "The private IP address assigned to the instance"
  value = module.ec2_instance.private_ip
}

output "private_dns" {
  description = "The private DNS name assigned to the instance. Can only be used inside the Amazon EC2, and only available if you've enabled DNS hostnames for your VPC"
  value = module.ec2_instance.private_dns
}

