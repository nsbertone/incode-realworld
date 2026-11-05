output "url" {
  value = local.https ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.bucket
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}
