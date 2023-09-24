provider "aws" {
  region = var.region
}

###############################################################################
## Init

locals {
  azs            = slice(data.aws_availability_zones.available.names, 0, 1)
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0)]
}

##
## Data discovery
##

data "aws_availability_zones" "available" {}

# data "aws_ami" "amazon_linux" {
#   most_recent = true
#   owners      = ["amazon"]
#
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

data "aws_ami" "single_vm" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

data "aws_iam_policy" "aws_ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "aws_cloudwatch_agent" {
  name = "CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "s3_endpoint_policy" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_caller_identity" "this" {}

###############################################################################
## VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = local.azs
  public_subnets          = local.public_subnets
  map_public_ip_on_launch = true
}

module "squid_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/squid"
  version = "~> 5.0"

  name                = "squid-sg"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  vpc_id              = module.vpc.vpc_id
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id                = module.vpc.vpc_id
  create_security_group = true

  security_group_rules = {
    # SSM system manager requires https (443) access to managed instances
    ingress_https = {
      cidr_blocks = [module.vpc.vpc_cidr_block]
      to_port     = 443
    }
    # EC2 instances need to be able to talk to VPC endpoints to reach SSM services
    egress = {
      cidr_blocks = [module.vpc.vpc_cidr_block]
      from_port   = 0
      to_port     = 0
      protocol    = -1
      type        = "egress"
    }
  }

  # Minimum set of enpoints that are needed for SSM to function
  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.public_route_table_ids
      # Allow access to data on S3 for SSM
      # Can be made more granular as described in
      # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html
      policy = data.aws_iam_policy_document.s3_endpoint_policy.json
    }
    ssm = {
      service             = "ssm"
      service_type        = "Interface"
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
    }
    ssmmessages = {
      service             = "ssmmessages"
      service_type        = "Interface"
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
    }
    ec2 = {
      service             = "ec2"
      service_type        = "Interface"
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
    }
    ec2messages = {
      service             = "ec2messages"
      service_type        = "Interface"
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
    }
    secretsmanager = {
      service             = "secretsmanager"
      service_type        = "Interface"
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
    }
  }
}

###############################################################################
## EC2 instance

module "server" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  ami           = data.aws_ami.single_vm.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [
    module.vpc_endpoints.security_group_id,
    module.squid_security_group.security_group_id,
  ]
  create_iam_instance_profile = true
  iam_role_name               = "ec2-server"
  iam_role_policies = {
    SSMCore         = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent = data.aws_iam_policy.aws_cloudwatch_agent.arn
  }
}

###############################################################################
## Secrets

module "secrets_manager" {
  source = "terraform-aws-modules/secrets-manager/aws"

  name = "squid_proxy_password"

  create_policy       = true
  block_public_policy = true

  policy_statements = {
    read = {
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.this.arn, module.server.iam_role_arn]
        }
      ]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }

  create_random_password           = true
  random_password_length           = 32
  random_password_override_special = ""

  recovery_window_in_days = 0
}

