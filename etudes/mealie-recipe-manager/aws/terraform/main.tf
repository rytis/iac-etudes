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
## ALB

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "mealie-service"
  vpc_id = module.vpc.vpc_id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = module.vpc.private_subnets_cidr_blocks
}

module "mealie_alb" {
  source = "terraform-aws-modules/alb/aws"

  name = "mealie"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name             = "mealie"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]
}

###############################################################################
## ECS

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

      port_mappings = [
        {
          name          = "mealie-container"   # must match container name
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  }

  subnet_ids = module.vpc.private_subnets
  # assign_public_ip = true

  security_group_rules = {
    # allow all outbound connections, needed to pull images from dockerhub
    # for images hosted on ecr prefereably use VPC endpoint to ECR
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # allow connection from the loadbalancer (source: alb sg)
    alb_ingress_80 = {
      type                     = "ingress"
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.mealie_alb.target_group_arns[0]
      container_name   = "mealie-container"    # must match container name
      container_port   = 80
    }
  }
}

