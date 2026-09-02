provider "aws" {
  # Defines the default deployment target region
  region = "eu-west-2"

  # Automatically injects these tags into every single resource that supports them
  default_tags {
    tags = var.resource_tags
  }
}
