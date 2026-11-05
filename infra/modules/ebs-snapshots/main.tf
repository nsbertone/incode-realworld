# Daily EBS snapshots with Data Lifecycle Manager, selected by tag (the gp3
# StorageClass tags every dynamically provisioned volume Backup=daily).
# Used where AWS Backup is not available; AWS Backup is preferred because it
# adds vault lock and cross-region copies.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${var.name}-dlm"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "daily" {
  description        = "${var.name} daily EBS snapshots by tag ${var.tag_key} ${var.tag_value}"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { (var.tag_key) = var.tag_value }

    schedule {
      name      = "daily"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.time_utc]
      }

      retain_rule {
        count = var.retention_days
      }
    }
  }

  tags = var.tags
}
