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

  name               = var.vpc_name
  cidr               = var.vpc_cidr
  azs                = local.azs
  public_subnets     = local.public_subnets
  private_subnets    = local.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

###############################################################################
## Dask cluster

module "dask_cluster" {
  source = "./modules/dask_cluster"

  vpc = module.vpc
}

###############################################################################
## Sagemaker Notebook

module "sagemaker_notebook" {
  source = "./modules/sagemaker_notebook"

  vpc            = module.vpc
  security_group = module.dask_cluster.dask_worker_security_group_id
}

###############################################################################
## Data store

module "data_store" {
  source = "./modules/data_store"

  region            = var.region
  notebook_role_arn = module.sagemaker_notebook.notebook_role_arn
}


