data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ---- CloudTrail: who did what in the account -------------------------------
resource "aws_s3_bucket" "cloudtrail" {
  bucket_prefix = "${var.name}-cloudtrail-"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration {
      days = var.log_retention_days
    }
  }
}

locals {
  trail_arn = "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.name}"
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid       = "AclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "Write"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

resource "aws_cloudtrail" "this" {
  name                          = var.name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  tags                          = var.tags

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ---- GuardDuty: threat detection -------------------------------------------
resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = var.tags
}

resource "aws_guardduty_detector_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "rds_login" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RUNTIME_MONITORING"
  status      = var.enable_guardduty_runtime_monitoring ? "ENABLED" : "DISABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = var.enable_guardduty_runtime_monitoring ? "ENABLED" : "DISABLED"
  }
}

# ---- IAM Access Analyzer: flags resources shared outside the account -------
resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "${var.name}-account"
  type          = "ACCOUNT"
  tags          = var.tags
}

# ---- Inspector: CVEs in what actually runs ----------------------------------
# EC2: the EKS nodes. The node role has no SSM permissions (no shell access to
# nodes), so Inspector uses agentless scanning of EBS snapshots (hybrid mode).
# ECR: replaces ECR basic scan-on-push with enhanced, continuous scanning, so
# an image already in the registry is re-checked when a new CVE is published.
# Findings flow to the console/EventBridge; the fix for a node finding is a
# newer EKS AMI (node group rolls), for an image finding a rebuild.
resource "aws_inspector2_enabler" "this" {
  count          = var.enable_inspector ? 1 : 0
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR"]
}
