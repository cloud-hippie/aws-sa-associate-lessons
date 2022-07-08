provider "aws" {
  region  = "us-east-1"
}

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket  = "cloud-hippie-terraform-state-bucket"
    key     = "ecr-publish-tfstate.tfstate"
    region  = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.21.0"
    }
  }
}
