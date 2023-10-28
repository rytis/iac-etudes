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

data "aws_iam_policy" "sagemaker_full" {
  name = "AmazonSageMakerFullAccess"
}

data "aws_iam_policy_document" "sagemaker_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "codepipeline.amazonaws.com",
        "cloudformation.amazonaws.com",
        "glue.amazonaws.com",
        "apigateway.amazonaws.com",
        "lambda.amazonaws.com",
        "sagemaker.amazonaws.com",
        "events.amazonaws.com",
        "states.amazonaws.com",
        "codebuild.amazonaws.com",
        "firehose.amazonaws.com"
      ]
    }
  }
}

module "sagemaker_notebook_instance_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  role_name = "sagemaker_notebook_instance_role"

  create_role = true

  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.sagemaker_trust.json
  custom_role_policy_arns = [
    data.aws_iam_policy.sagemaker_full.arn
  ]
}

resource "aws_sagemaker_notebook_instance" "this" {
  name                   = "dask-notebook"
  role_arn               = module.sagemaker_notebook_instance_role.iam_role_arn
  instance_type          = "ml.t3.medium"
  subnet_id              = module.vpc.private_subnets[0]
  security_groups        = [module.dask_cluster.dask_worker_security_group_id]
  direct_internet_access = "Disabled"
}
