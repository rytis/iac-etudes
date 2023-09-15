provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  vpc_name = var.vpc_name
  region   = var.region
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 1)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name           = local.vpc_name
  cidr           = local.vpc_cidr
  azs            = local.azs
  public_subnets = [cidrsubnet(local.vpc_cidr, 8, 0)]
}

#data "aws_ami" "amazon_linux" {
#  most_recent = true
#  owners      = ["amazon"]
#
#  filter {
#    name   = "name"
#    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#  }
#}
#
#module "server" {
#  source        = "terraform-aws-modules/ec2-instance/aws"
#  ami           = data.aws_ami.amazon_linux.id
#  instance_type = "t2.micro"
#  subnet_id     = module.vpc.public_subnets[0]
#}
#
