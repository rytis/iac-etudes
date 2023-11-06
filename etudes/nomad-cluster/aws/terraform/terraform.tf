terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    key            = "terraform.state"
    bucket         = "rsi-iac-etudes-nomad-cluster"
    dynamodb_table = "rsi-iac-etudes-nomad-cluster"
  }
}
