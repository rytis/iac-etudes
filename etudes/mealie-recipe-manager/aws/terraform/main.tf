provider "aws" {
  region = var.region
}

###############################################################################
## Init

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 0),
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2)
  ]
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 3),
    cidrsubnet(var.vpc_cidr, 8, 4),
    cidrsubnet(var.vpc_cidr, 8, 5)
  ]
  db_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 6),
    cidrsubnet(var.vpc_cidr, 8, 7),
    cidrsubnet(var.vpc_cidr, 8, 8)
  ]
}

###############################################################################
## VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name             = var.vpc_name
  cidr             = var.vpc_cidr
  azs              = local.azs
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.db_subnets
  #   enable_nat_gateway = true
  #   single_nat_gateway = true
}

###############################################################################
## Frontend

# module "mealie_frontend" {
#   source = "./modules/frontend"
#
#   vpc = module.vpc
# }

###############################################################################
## Database

module "mealie_db" {
  source = "./modules/db"

  vpc = module.vpc
}

