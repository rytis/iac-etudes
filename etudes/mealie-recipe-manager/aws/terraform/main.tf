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
## ECS cluster

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"

  cluster_name = "mealie-recipe-manager"

  fargate_capacity_providers = {
    FARGATE = {}
  }
}

module "mealie_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = "mealie-service"
  cluster_arn = module.ecs_cluster.arn

  container_definitions = {
    mealie = {
      name                     = "mealie-container"
      cpu                      = 512
      memory                   = 1024
      essential                = true
      readonly_root_filesystem = false

      image = "docker.io/nginx"
    }
  }

  subnet_ids = module.vpc.private_subnets
  # assign_public_ip = true

  security_group_rules = {
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

