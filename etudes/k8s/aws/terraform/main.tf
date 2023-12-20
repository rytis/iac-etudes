provider "aws" {
  region = var.region
}


###############################################################################
## Init

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 0),
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2)
  ]
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 3),
    cidrsubnet(var.vpc_cidr, 8, 4),
    cidrsubnet(var.vpc_cidr, 8, 5)
  ]
}

###############################################################################
## VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = local.azs
  public_subnets          = local.public_subnets
  private_subnets         = local.private_subnets
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
}

###############################################################################
## EKS

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = "test-eks"
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
    aws-efs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.irsa-efs-csi.iam_role_arn
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3a.small"]
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    iam_role_additional_policies = {
      efs_full_client = data.aws_iam_policy.aws_efs_full.arn
    }
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"
    }
    two = {
      name = "node-group-2"
    }
  }

}

data "aws_iam_policy" "aws_efs_full" {
  name = "AmazonElasticFileSystemClientFullAccess"
}

## -- EBS ----

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role                   = true
  role_name                     = "Amazon-EKS-TF-EBS-CSI-Role-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

## -- EFS ----

data "aws_iam_policy" "efs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

module "irsa-efs-csi" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role                   = true
  role_name                     = "Amazon-EKS-TF-EFS-CSI-Role-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.efs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
}

module "efs_volume" {
  source = "terraform-aws-modules/efs/aws"

  name = "k8s-data"

  mount_targets = { for k, v in zipmap(module.vpc.azs, module.vpc.private_subnets) : k => { subnet_id = v } }

  security_group_vpc_id = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }
}

## TEST EC2 instance

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

module "efs_client" {
  source = "terraform-aws-modules/ec2-instance/aws"

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3a.micro"
  subnet_id     = module.vpc.private_subnets[0]

  create_iam_instance_profile = true
  iam_role_name               = "ec2-test-host"
  iam_role_policies = {
    SSMCore         = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent = data.aws_iam_policy.aws_cloudwatch_agent.arn
    EFSClient       = data.aws_iam_policy.aws_efs_full.arn
  }

  vpc_security_group_ids = [module.ssm_sg.security_group_id]
}

module "ssm_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name                = "sg for ssm"
  vpc_id              = module.vpc.vpc_id
  egress_rules        = ["https-443-tcp", "nfs-tcp"]
  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
}
