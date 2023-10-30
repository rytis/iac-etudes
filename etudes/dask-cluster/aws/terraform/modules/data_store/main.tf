data "aws_caller_identity" "current" {}
resource "random_pet" "this" {}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [var.notebook_role_arn]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${local.bucket_name}/*"
    ]
  }
}

locals {
  bucket_name = "dask-data-${random_pet.this.id}"
}

module "dask_data" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = local.bucket_name
  force_destroy = true

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json
}
