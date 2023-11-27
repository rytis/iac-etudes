provider "aws" {
  region = var.region
}


###############################################################################
## Init

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets_a = [
    cidrsubnet(var.vpc_a_cidr, 8, 0),
    cidrsubnet(var.vpc_a_cidr, 8, 1),
    cidrsubnet(var.vpc_a_cidr, 8, 2)
  ]
  private_subnets_a = [
    cidrsubnet(var.vpc_a_cidr, 8, 3),
    cidrsubnet(var.vpc_a_cidr, 8, 4),
    cidrsubnet(var.vpc_a_cidr, 8, 5)
  ]
  public_subnets_b = [
    cidrsubnet(var.vpc_b_cidr, 8, 0),
    cidrsubnet(var.vpc_b_cidr, 8, 1),
    cidrsubnet(var.vpc_b_cidr, 8, 2)
  ]
  private_subnets_b = [
    cidrsubnet(var.vpc_b_cidr, 8, 3),
    cidrsubnet(var.vpc_b_cidr, 8, 4),
    cidrsubnet(var.vpc_b_cidr, 8, 5)
  ]
}

###############################################################################
## VPC

module "vpc_a" {
  source = "terraform-aws-modules/vpc/aws"

  name               = var.vpc_a_name
  cidr               = var.vpc_a_cidr
  azs                = local.azs
  public_subnets     = local.public_subnets_a
  private_subnets    = local.private_subnets_a
  enable_nat_gateway = true
  single_nat_gateway = true
  map_public_ip_on_launch = true
}

module "vpc_b" {
  source = "terraform-aws-modules/vpc/aws"

  name               = var.vpc_b_name
  cidr               = var.vpc_b_cidr
  azs                = local.azs
  public_subnets     = local.public_subnets_b
  private_subnets    = local.private_subnets_b
  enable_nat_gateway = true
  single_nat_gateway = true
  map_public_ip_on_launch = true
}


###############################################################################
## Test EC2 instances

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_iam_policy" "aws_ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "aws_cloudwatch_agent" {
  name = "CloudWatchAgentServerPolicy"
}

module "test_sg_a" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "test-sg-a"
  vpc_id = module.vpc_a.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

module "test_sg_b" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "test-sg-b"
  vpc_id = module.vpc_b.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

module "server_a" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "server_a"
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc_a.public_subnets[0]
  vpc_security_group_ids = [module.test_sg_a.security_group_id]

  create_iam_instance_profile = true
  iam_role_name               = "vpc_a_test"
  iam_role_policies = {
    SSMCore         = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent = data.aws_iam_policy.aws_cloudwatch_agent.arn
  }
}

module "server_b" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "server_b"
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc_b.public_subnets[0]
  vpc_security_group_ids = [module.test_sg_b.security_group_id]

  create_iam_instance_profile = true
  iam_role_name               = "vpc_b_test"
  iam_role_policies = {
    SSMCore         = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent = data.aws_iam_policy.aws_cloudwatch_agent.arn
  }
}

###############################################################################
## Client VPN

# module "client_vpn" {
#   source = "./modules/client"
#
#   vpc                          = module.vpc
#   client_cidr                  = var.client_cidr
#   number_of_associated_subnets = length(local.public_subnets)
# }

###############################################################################
## Site-to-Site VPN

module "site_to_site_vpn" {
  source = "./modules/site"

  vpc_a = module.vpc_a
  vpc_b = module.vpc_b
}
