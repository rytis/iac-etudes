
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
  vpc_id = var.vpc_a.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

module "test_sg_b" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "test-sg-b"
  vpc_id = var.vpc_b.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

module "server_a" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "server_a"
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = var.vpc_a.public_subnets[0]
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
  subnet_id              = var.vpc_b.public_subnets[0]
  vpc_security_group_ids = [module.test_sg_b.security_group_id]

  create_iam_instance_profile = true
  iam_role_name               = "vpc_b_test"
  iam_role_policies = {
    SSMCore         = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent = data.aws_iam_policy.aws_cloudwatch_agent.arn
  }
}

