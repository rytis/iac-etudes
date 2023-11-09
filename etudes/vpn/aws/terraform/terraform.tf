terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    key            = "terraform.state"
    bucket         = "rsi-iac-etudes-vpn"
    dynamodb_table = "rsi-iac-etudes-vpn"
  }
}
