module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "mealie"

  engine               = "postgres"
  engine_version       = "15"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.t4g.micro"

  allocated_storage = 20

  db_name  = "mealie"
  username = "mealie"
  port     = 5432

  multi_az = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
}
