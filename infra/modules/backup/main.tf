# Daily AWS Backup of everything tagged Backup=daily (RDS, S3 buckets, EBS
# volumes created by the EBS CSI StorageClass), copied to a second region.
# This complements, not replaces, RDS automated backups (PITR).

resource "aws_backup_vault" "primary" {
  name          = "${var.name}-primary"
  force_destroy = true
  tags          = var.tags
}

resource "aws_backup_vault" "dr" {
  provider = aws.dr

  name          = "${var.name}-dr"
  force_destroy = true
  tags          = var.tags
}

# Governance mode (no changeable_for_days): protects against accidental or
# malicious deletion while still allowing teardown of this lab. In production
# use compliance mode (set changeable_for_days) so the lock becomes immutable.
resource "aws_backup_vault_lock_configuration" "primary" {
  count = var.vault_lock_min_days == null ? 0 : 1

  backup_vault_name  = aws_backup_vault.primary.name
  min_retention_days = var.vault_lock_min_days
  max_retention_days = max(var.retention_days, var.dr_copy_retention_days)
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = var.schedule
    start_window      = 60
    completion_window = 240

    lifecycle {
      delete_after = var.retention_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
      lifecycle {
        delete_after = var.dr_copy_retention_days
      }
    }

    recovery_point_tags = var.tags
  }

  tags = var.tags
}

data "aws_iam_policy_document" "backup_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
    "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
    "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup",
    "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore",
  ])

  role       = aws_iam_role.backup.name
  policy_arn = each.value
}

resource "aws_backup_selection" "tagged" {
  name         = "${var.name}-tagged"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.selection_tag_key
    value = var.selection_tag_value
  }
}
