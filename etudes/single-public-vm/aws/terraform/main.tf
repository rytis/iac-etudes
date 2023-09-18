provider "aws" {
  region = var.region
}

###############################################################################
## Init

locals {
  azs            = slice(data.aws_availability_zones.available.names, 0, 1)
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0)]
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

  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = local.azs
  public_subnets          = local.public_subnets
  map_public_ip_on_launch = true
}

###############################################################################
## EC2 instance

module "server" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnets[0]
}

