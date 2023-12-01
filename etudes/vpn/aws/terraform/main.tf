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

  name                    = var.vpc_a_name
  cidr                    = var.vpc_a_cidr
  azs                     = local.azs
  public_subnets          = local.public_subnets_a
  private_subnets         = local.private_subnets_a
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
  customer_gateways = {
    gw1 = {
      bgp_asn    = 65211
      ip_address = var.client_gw_ip
    }
  }
}

module "vpc_b" {
  source = "terraform-aws-modules/vpc/aws"

  name                    = var.vpc_b_name
  cidr                    = var.vpc_b_cidr
  azs                     = local.azs
  public_subnets          = local.public_subnets_b
  private_subnets         = local.private_subnets_b
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
}

###############################################################################
## Transit Gateway

module "transit_gateway" {
  source = "./modules/transit-gw"

  vpc_a                      = module.vpc_a
  vpc_b                      = module.vpc_b
  number_of_public_subnets_a = length(local.public_subnets_a)
  number_of_public_subnets_b = length(local.public_subnets_b)
}

###############################################################################
## Test EC2 instances

module "test_instances" {
  source = "./modules/testing"

  vpc_a = module.vpc_a
  vpc_b = module.vpc_b
}

###############################################################################
## Client VPN

module "client_vpn" {
  source = "./modules/client"

  vpc                          = module.vpc_a
  client_cidr                  = var.client_cidr
  number_of_associated_subnets = length(local.public_subnets_a)
}

###############################################################################
## Site VPN

# TODO: test with remote VPN

module "site_vpn" {
  source = "./modules/site"

  vpc_a = module.vpc_a
  vpc_b = module.vpc_b

  transit_gateway = module.transit_gateway.transit_gw
}
