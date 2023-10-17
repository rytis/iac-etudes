

###############################################################################
## ECS

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"

  cluster_name = "dask-cluster"

  fargate_capacity_providers = {
    FARGATE = {}
  }

  cluster_service_connect_defaults = {
    namespace = "dask-cluster"
  }
}

# -----------------------------------------------------------------------------
#   Scheduler

module "dask_scheduler_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = "dask-scheduler-service"
  cluster_arn = module.ecs_cluster.arn

  container_definitions = {
    dask_scheduler = {
      name                     = "dask-scheduler"
      cpu                      = 512
      memory                   = 2048
      essential                = true
      readonly_root_filesystem = false

      image   = "ghcr.io/dask/dask:latest"
      command = ["scheduler"]
    }
  }

  subnet_ids = var.vpc.private_subnets

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
  }
}

# -----------------------------------------------------------------------------
#   Worker

# module "dask_worker_service" {
#   source = "terraform-aws-modules/ecs/aws//modules/service"
#
#   name        = "dask-worker-service"
#   cluster_arn = module.ecs_cluster.arn
#
#   container_definitions = {
#     dask_scheduler = {
#       name                     = "dask-worker"
#       cpu                      = 512
#       memory                   = 2048
#       essential                = true
#       readonly_root_filesystem = false
#
#       image   = "ghcr.io/dask/dask:latest"
#       command = ["???"]
#     }
#   }
#
#   subnet_ids = var.vpc.private_subnets
#
#   enable_execute_command = true
#
#   # add policy to allow access to ssm, which is needed for ecs exec to function
#   # the policy is added to task role, do not confuse with `task_exec_iam_statements`
#   # which is a role used to execute task (and not the role assumed by running task)
#   tasks_iam_role_statements = {
#     ssm = {
#       actions = [
#         "ssmmessages:CreateControlChannel",
#         "ssmmessages:CreateDataChannel",
#         "ssmmessages:OpenControlChannel",
#         "ssmmessages:OpenDataChannel"
#       ]
#       resources = ["*"]
#       effect    = "Allow"
#     }
#   }
#
#   security_group_rules = {
#     # allow all outbound connections, needed to pull images from dockerhub
#     # for images hosted on ecr prefereably use VPC endpoint to ECR
#     egress_all = {
#       type        = "egress"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   }
# }
