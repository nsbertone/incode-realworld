output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "build_role_arn" {
  value = aws_iam_role.build.arn
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}
