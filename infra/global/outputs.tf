output "tfstate_bucket" {
  description = "Bucket for all other stacks' remote state."
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
