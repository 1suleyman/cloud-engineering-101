terraform {
  # Specifies the CLI tool engines required
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      # The official primary repository location on the registry
      source  = "hashicorp/aws" 
      # keeping the AWS provider within major version 6
      version = "~> 6.0"       
    }
  }
}