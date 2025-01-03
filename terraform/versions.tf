terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "rv-terraform-state-bucket"        # Same as shared infra
    key            = "edge/terraform.tfstate"           # Unique key for the edge service
    region         = "eu-central-1"                      
    dynamodb_table = "terraform-locks"                   # DynamoDB table for edge locking
    encrypt        = true
    profile        = "rv-terraform"
  }
}

provider "aws" {
  region    = var.aws_region
  profile   = "rv-terraform"
}