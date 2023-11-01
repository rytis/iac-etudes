data "aws_ami" "nomad" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

module "nomad_worker" {
  source = "terraform-aws-modules/ec2-instance/aws"

  count = length(var.subnets)

  ami           = data.aws_ami.nomad.id
  instance_type = "t2.micro"

  key_name               = var.ssh_key_name
  subnet_id              = var.subnets[count.index]
  vpc_security_group_ids = var.security_groups

  metadata_options = {
    "instance_metadata_tags" = "enabled"
  }
  instance_tags = var.tags

  create_iam_instance_profile = true
  iam_role_name               = "nomad-auto-cluster"
  iam_role_policies = {
    NomadClusterAutodiscovery = aws_iam_policy.nomad_cluster_auto_discovery.arn
    SSMCore                   = data.aws_iam_policy.aws_ssm_core.arn
    CloudWatchAgent           = data.aws_iam_policy.aws_cloudwatch_agent.arn
  }

  user_data = templatefile("${path.module}/worker-bootstrap.sh", {
    ansible_cloud_init_env = local.nomad_worker_bootstrap_env
  })
}

locals {
  nomad_worker_bootstrap_env = {
    ans_ci_nomad_cluster_autojoin_str = var.autojoin_string
  }
}

data "aws_iam_policy_document" "nomad_cluster_auto_discovery" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups"
    ]
  }
}

resource "aws_iam_policy" "nomad_cluster_auto_discovery" {
  name        = "nomad-worker-autodiscovery"
  description = "Policy to allow autodiscovery of Nomad cluster nodes"
  policy      = data.aws_iam_policy_document.nomad_cluster_auto_discovery.json
}

data "aws_iam_policy" "aws_ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "aws_cloudwatch_agent" {
  name = "CloudWatchAgentServerPolicy"
}
