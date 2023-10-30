output "notebook_url" {
  value = aws_sagemaker_notebook_instance.this.url
}

output "notebook_role_arn" {
  value = module.sagemaker_notebook_instance_role.iam_role_arn
}
