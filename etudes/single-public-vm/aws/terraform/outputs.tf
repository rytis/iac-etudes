output "user_arn" {
  value = data.aws_iam_user.this.arn
}

output "caller_arn" {
  value = data.aws_caller_identity.this.arn
}
