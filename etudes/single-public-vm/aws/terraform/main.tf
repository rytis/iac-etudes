provider "aws" {
  region = local.region
}

###############################################################################
## Init

locals {
  vpc_name       = var.vpc_name
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  instance_type  = var.instance_type
  azs            = slice(data.aws_availability_zones.available.names, 0, 1)
  public_subnets = [cidrsubnet(local.vpc_cidr, 8, 0)]
}

## Data discovery

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

###############################################################################
## VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name           = local.vpc_name
  cidr           = local.vpc_cidr
  azs            = local.azs
  public_subnets = local.public_subnets
}

###############################################################################
## EC2 instance

module "server" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type
  subnet_id     = module.vpc.public_subnets[0]
}

