provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = var.vpc_azs
  private_subnets         = var.vpc_private_subnets
  public_subnets          = var.vpc_public_subnets
  map_public_ip_on_launch = true
  enable_nat_gateway      = true
}

module "nomad_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/nomad"
  version = "~> 5.0"

  name = "nomad-sg"
  ingress_cidr_blocks = concat(
    module.vpc.public_subnets_cidr_blocks,
    module.vpc.private_subnets_cidr_blocks
  )
  vpc_id = module.vpc.vpc_id
}

module "ssh_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "~> 5.0"

  name                = "ssh-sg"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  vpc_id              = module.vpc.vpc_id
}

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "~> 5.0"

  name                = "lb-sg"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  vpc_id              = module.vpc.vpc_id
}

module "nomad_ui_lb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 4.0"

  name                = "lb-nomad-ui"
  security_groups     = [module.lb_security_group.security_group_id]
  subnets             = module.vpc.public_subnets
  number_of_instances = length(module.nomad_control_plane.instance_ids)
  instances           = module.nomad_control_plane.instance_ids

  listener = [{
    instance_port     = "4646"
    instance_protocol = "HTTP"
    lb_port           = "80"
    lb_protocol       = "HTTP"
  }]

  health_check = {
    target              = "HTTP:4646/ui/"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }
}

module "ssh_key" {
  source = "./modules/ssh"
}

module "nomad_control_plane" {
  source = "./modules/nomad_control_plane"

  ami_name = var.nomad_server_ami_name
  subnets  = module.vpc.public_subnets

  security_groups = [
    module.nomad_security_group.security_group_id,
    module.ssh_security_group.security_group_id
  ]

  tags            = var.nomad_server_tags
  autojoin_string = var.nomad_cloud_autojoin_string

  ssh_key_name = module.ssh_key.key_name
}

module "nomad_worker_pool" {
  source = "./modules/nomad_worker_pool"

  ami_name = var.nomad_worker_ami_name
  subnets  = module.vpc.private_subnets

  security_groups = [
    module.nomad_security_group.security_group_id,
    module.ssh_security_group.security_group_id
  ]

  tags            = var.nomad_worker_tags
  autojoin_string = var.nomad_cloud_autojoin_string

  ssh_key_name = module.ssh_key.key_name
}

module "cluster_configuration" {
  source = "./modules/cluster_services"

  nomad_address = "http://${module.nomad_ui_lb.elb_dns_name}/"
}
