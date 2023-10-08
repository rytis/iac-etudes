locals {
  db_username = "mealie"
  db_password = random_password.db_password.result
}

# module "db" {
#   source = "terraform-aws-modules/rds/aws"
#
#   identifier = "mealie"
#
#   engine               = "postgres"
#   engine_version       = "15"
#   family               = "postgres15"
#   major_engine_version = "15"
#   instance_class       = "db.t4g.micro"
#   allocated_storage    = 20
#
#   db_name                     = "mealie"
#   port                        = 5432
#   username                    = local.db_username
#   password                    = local.db_password
#   manage_master_user_password = false
#
#   iam_database_authentication_enabled = false
#
#   enabled_cloudwatch_logs_exports = ["postgresql"]
#   create_cloudwatch_log_group     = true
#
#   # multi_az = true
#   backup_retention_period = 0
#   skip_final_snapshot     = true
#   deletion_protection     = false
#
#   db_subnet_group_name   = var.vpc.database_subnet_group
#   vpc_security_group_ids = [module.ecs_private_sg.security_group_id]
#
#   ca_cert_identifier = "rds-ca-ecc384-g1" # otherwise will default to 2019 CA
# }
#
# module "ecs_private_sg" {
#   source = "terraform-aws-modules/security-group/aws"
#
#   name   = "mealie-containers"
#   vpc_id = var.vpc.vpc_id
#
#   ingress_cidr_blocks = var.vpc.private_subnets_cidr_blocks
#   ingress_rules       = ["postgresql-tcp"]
# }

module "db_secret" {
  source = "terraform-aws-modules/secrets-manager/aws"

  name                    = "mealie_db_credentials"
  recovery_window_in_days = 0

  create_policy       = true
  block_public_policy = true
  policy_statements = {
    read = {
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.this.arn]
        }
      ]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }

  secret_string = jsonencode({
    username = local.db_username
    password = local.db_password
  })

}

data "aws_caller_identity" "this" {}

resource "random_password" "db_password" {
  length  = 32
  special = false
}