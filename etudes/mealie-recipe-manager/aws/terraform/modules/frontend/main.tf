locals {
  vpc = var.vpc
}

###############################################################################
## ALB

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "frontend-service-sg"
  vpc_id = local.vpc.vpc_id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = local.vpc.private_subnets_cidr_blocks
}

module "frontend_alb" {
  source = "terraform-aws-modules/alb/aws"

  name = "mealie-frontend"

  load_balancer_type = "application"

  vpc_id          = local.vpc.vpc_id
  subnets         = local.vpc.public_subnets
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
      name             = "mealie-frontend"
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

module "mealie_frontend_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = "mealie-service"
  cluster_arn = module.ecs_cluster.arn

  container_definitions = {
    mealie = {
      name                     = "mealie-frontend"
      cpu                      = 512
      memory                   = 1024
      essential                = true
      readonly_root_filesystem = false

      image = "docker.io/nginx"

      port_mappings = [
        {
          name          = "mealie-frontend" # must match container name
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  }

  subnet_ids = local.vpc.private_subnets

  desired_count            = 3
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 6

  enable_execute_command = true
  # add policy to allow access to ssm, which is needed for ecs exec to function
  # the policy is added to task role, do not confuse with `task_exec_iam_statements`
  # which is a role used to execute task (and not the role assumed by running task)
  tasks_iam_role_statements = {
    ssm = {
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      resources = ["*"]
      effect    = "Allow"
    }
  }

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
      target_group_arn = module.frontend_alb.target_group_arns[0]
      container_name   = "mealie-frontend" # must match container name
      container_port   = 80
    }
  }
}

