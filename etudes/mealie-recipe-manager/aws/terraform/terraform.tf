terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    key            = "terraform.state"
    bucket         = "rsi-iac-etudes-mealie-recipe-manager"
    dynamodb_table = "rsi-iac-etudes-mealie-recipe-manager"
  }
}
