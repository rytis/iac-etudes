
data "aws_iam_policy" "sagemaker_full" {
  name = "AmazonSageMakerFullAccess"
}

data "aws_iam_policy_document" "sagemaker_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "codepipeline.amazonaws.com",
        "cloudformation.amazonaws.com",
        "glue.amazonaws.com",
        "apigateway.amazonaws.com",
        "lambda.amazonaws.com",
        "sagemaker.amazonaws.com",
        "events.amazonaws.com",
        "states.amazonaws.com",
        "codebuild.amazonaws.com",
        "firehose.amazonaws.com"
      ]
    }
  }
}

module "sagemaker_notebook_instance_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  role_name = "sagemaker_notebook_instance_role"

  create_role = true

  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.sagemaker_trust.json
  custom_role_policy_arns = [
    data.aws_iam_policy.sagemaker_full.arn
  ]
}

resource "aws_sagemaker_notebook_instance" "this" {
  name                   = "dask-notebook"
  role_arn               = module.sagemaker_notebook_instance_role.iam_role_arn
  instance_type          = "ml.t3.medium"
  subnet_id              = var.vpc.private_subnets[0]
  security_groups        = [var.security_group]
  direct_internet_access = "Disabled"
}

