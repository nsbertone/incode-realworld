# AWS-side pieces for the in-cluster observability stack:
#   - S3 bucket for Loki chunks/index (no disks to manage, cheap retention)
#   - SNS topic that Alertmanager publishes to
# The IRSA roles that use them are created in the env stack.

resource "aws_s3_bucket" "loki" {
  bucket_prefix = "${var.name}-loki-"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration {
      days = var.loki_retention_days + 1
    }
  }
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
