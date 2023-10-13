###############################################################################
## Init

locals {
  vpc              = var.vpc
  application_port = 9000
}

data "aws_iam_policy" "efs" {
  name = "AmazonElasticFileSystemClientFullAccess"
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

  name_prefix = "fe-"

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
      name_prefix      = "fe-"
      backend_protocol = "HTTP"
      backend_port     = local.application_port
      target_type      = "ip"
    }
  ]
}

###############################################################################
## EFS

module "frontend_efs" {
  source = "terraform-aws-modules/efs/aws"

  name = "mealie-data"

  mount_targets = { for k, v in zipmap(local.vpc.azs, local.vpc.private_subnets) : k => { subnet_id = v } }

  security_group_vpc_id = local.vpc.vpc_id
  security_group_rules = {
    vpc = {
      cidr_blocks = local.vpc.private_subnets_cidr_blocks
    }
  }

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

  # by default efs module will create fs policy that prevents
  # non encrypted connections, therefore we need to ENABLE
  # transit_encryption and also set IAM authentication
  volume = {
    mealie_data = { # the volume will be named "mealie_data", so we'll need to reference it by that name
      efs_volume_configuration = {
        file_system_id     = module.frontend_efs.id
        transit_encryption = "ENABLED"
        authorization_config = {
          "iam" = "ENABLED"
        }
      }
    }
  }

  container_definitions = {
    mealie = {
      name                     = "mealie-frontend"
      cpu                      = 512
      memory                   = 1024
      essential                = true
      readonly_root_filesystem = false

      # image   = "docker.io/fedora"
      # command = ["sleep", "infinity"]
      image = "ghcr.io/mealie-recipes/mealie:nightly"

      mount_points = [
        {
          sourceVolume  = "mealie_data" # literal string matching volume name in `volume {...}` definition
          containerPath = "/app/data"
        }
      ]

      port_mappings = [
        {
          name          = "mealie-frontend" # must match container name
          containerPort = local.application_port
          hostPort      = local.application_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_ENGINE"
          value = "postgres"
        }
      ]

      secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
        },
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_DB"
          valueFrom = "${var.db_secret_arn}:name::"
        },
        {
          name      = "POSTGRES_PORT"
          valueFrom = "${var.db_secret_arn}:port::"
        },
        {
          name      = "POSTGRES_SERVER"
          valueFrom = "${var.db_secret_arn}:address::"
        },
      ]
    }
  }

  subnet_ids = local.vpc.private_subnets

  desired_count            = 3
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 9

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

  # attach EFS client policy so that we're allowed to mount
  # without this we'd get permission denied
  # and it needs to be tasks role and not task exec role
  tasks_iam_role_policies = {
    esf = data.aws_iam_policy.efs.arn
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
      from_port                = local.application_port
      to_port                  = local.application_port
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  }

  load_balancer = {
    api = {
      target_group_arn = module.frontend_alb.target_group_arns[0]
      container_name   = "mealie-frontend" # must match container name
      container_port   = local.application_port
    }
  }
}
