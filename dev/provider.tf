## Terraform/Provider Version 
terraform {
  required_version = "~> 0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

/* Using default AWS config , you can change it to any 
other config based on local profile setting */

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

