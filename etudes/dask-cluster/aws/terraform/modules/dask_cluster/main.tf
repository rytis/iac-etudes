

###############################################################################
## ECS

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "dask-cluster.local"
  vpc  = var.vpc.vpc_id
}

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"

  cluster_name = "dask-cluster"

  fargate_capacity_providers = {
    FARGATE = {}
  }

  cluster_service_connect_defaults = {
    namespace = aws_service_discovery_private_dns_namespace.this.arn
  }
}

# -----------------------------------------------------------------------------
#   Scheduler

module "dask_scheduler_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = "dask-scheduler-service"
  cluster_arn = module.ecs_cluster.arn

  memory = 4096

  container_definitions = {
    dask_scheduler = {
      name                     = "dask-scheduler"
      cpu                      = 512
      memory                   = 4096
      essential                = true
      readonly_root_filesystem = false

      image   = "ghcr.io/dask/dask:latest"
      command = ["dask", "scheduler"]

      port_mappings = [
        {
          name          = "dask-scheduler-ui"
          containerPort = 8787
          hostPort      = 8787
          protocol      = "tcp"
        },
        {
          name          = "dask-scheduler"
          containerPort = 8786
          hostPort      = 8786
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "EXTRA_PIP_PACKAGES"
          value = "aiohttp"
        }
      ]
    }
  }

  service_connect_configuration = {
    enabled = true
    service = {
      client_alias = {
        port     = 8786
        dns_name = "scheduler-service"
      }
      port_name      = "dask-scheduler"
      discovery_name = "scheduler-service"
    }
  }

  service_registries = {
    registry_arn = aws_service_discovery_service.dask_scheduler.arn
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
        "ssmmessages:OpenDataChannel",
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
    ingress_all = {
      type        = "ingress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = var.vpc.private_subnets_cidr_blocks
    }
  }
}

# -----------------------------------------------------------------------------
#   Worker

module "dask_worker_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = "dask-worker-service"
  cluster_arn = module.ecs_cluster.arn

  service_connect_configuration = {
    enabled = true
  }

  memory = 4096

  depends_on = [module.dask_scheduler_service]

  desired_count            = 1
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 9

  container_definitions = {
    dask_scheduler = {
      name                     = "dask-worker"
      cpu                      = 512
      memory                   = 4096
      essential                = true
      readonly_root_filesystem = false

      # image   = "docker.io/fedora"
      # command = ["sleep", "infinity"]

      image = "ghcr.io/dask/dask:latest"

      # when dask worker starts it checks what interface/address to use when connecting to the scheduler.
      # in this instance scheduler is made available via Service Connect. Service Connect works by running
      # proxy in a sidecar container. sidecar container gets loopback address assigned to it
      # (such as 127.255.0.1 or similar), which means that by default worker process will bind to
      # loopback address on the worker instance (127.0.0.1). the worker then advertises that address
      # to the scheduler, and obviously the scheduler will not be able to connect back to the worker
      # (and also all workers will be masked behind the same 127.0.0.1 address).
      # therefore we set --host option explicitly to the primary interface on the container, which is
      # accessible from the scheduler. any outgoing connections will still be correctly routed to
      # the Serivce Connect proxy.
      command = [
        "/bin/bash",
        "-c",
        "dask worker scheduler-service:8786 --memory-limit 2048MB --worker-port 9000 --nanny-port 9001 --host $(hostname)",
      ]

      environment = [
        {
          name  = "EXTRA_PIP_PACKAGES"
          value = "aiohttp"
        }
      ]
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
        "ssmmessages:OpenDataChannel",
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
    ingress_all = {
      type        = "ingress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = var.vpc.private_subnets_cidr_blocks
    }
  }
}

resource "aws_service_discovery_service" "dask_scheduler" {
  name = "scheduler"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 5
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 5
  }
}
