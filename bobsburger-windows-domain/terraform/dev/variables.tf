
variable "resource_tags" {
  type = map(string)
}

# VPC
variable "vpc_name" {
  type    = string
}

variable "vpc_cidr" {
  type    = string
}

variable "availability_zones" {
  type    = list(string)
}

variable "private_subnet_cidrs" {
  type    = list(string)
}

# Security Groups

variable "sg_name" {
  type    = string
}

variable "sg_description" {
  type    = string
}

variable "ingress_rules" {
  description = "Map of ingress rules to add to the security group"
  type = map(object({
    name = optional(string)

    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ingress_rules :
      length(compact([v.cidr_ipv4, v.cidr_ipv6, v.prefix_list_id, v.referenced_security_group_id])) == 1
    ])
    error_message = "Each ingress rule must set exactly one of cidr_ipv4, cidr_ipv6, prefix_list_id, or referenced_security_group_id."
  }
}

variable "egress_rules" {
  description = "Map of egress rules to add to the security group"
  type = map(object({
    name = optional(string)

    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.egress_rules :
      length(compact([v.cidr_ipv4, v.cidr_ipv6, v.prefix_list_id, v.referenced_security_group_id])) == 1
    ])
    error_message = "Each egress rule must set exactly one of cidr_ipv4, cidr_ipv6, prefix_list_id, or referenced_security_group_id."
  }
}
