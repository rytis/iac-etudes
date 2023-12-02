terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    key            = "terraform.state"
    bucket         = "rsi-iac-etudes-k8s"
    dynamodb_table = "rsi-iac-etudes-k8s"
  }
}
