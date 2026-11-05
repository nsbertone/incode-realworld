data "aws_caller_identity" "current" {}

# ---- ECR -------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = "${var.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # a tag always means the same image (git SHA)
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}

# ---- GitHub Actions roles (OIDC, no static keys) ---------------------------
data "aws_iam_policy_document" "build_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only pushes to the build branch of this exact repo.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.build_branch}"]
    }
  }
}

resource "aws_iam_role" "build" {
  name               = "${var.name}-gha-build"
  assume_role_policy = data.aws_iam_policy_document.build_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "build" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "ecr-push"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build.json
}

# Read-only role for `terraform plan` on pull requests (apply stays manual).
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # GitHub does not issue OIDC tokens to pull requests from forks.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:ref:refs/heads/${var.build_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.name}-gha-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "StateLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.tfstate_bucket}/*.tflock"]
  }
  statement {
    sid       = "RefreshSecretVersions"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan-extras"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}
