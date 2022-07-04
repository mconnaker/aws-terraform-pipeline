terraform {
    required_providers {
      aws = {
        source   = "hashicorp/aws"
        version  = "~> 3.0"
      }
    }
}

provider "aws" {
    region = "us-east-1"
}

terraform {
  backend "s3"{
    bucket          = "tfstate-mc"
    key             = "terraform.tfstate"
    region          = "us-east-1"
    dynamodb_table  = "app-state"
  }
}
