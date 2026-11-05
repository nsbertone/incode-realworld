# One IAM role per in-cluster component, each trusted only by its own
# namespace/service account. Names must match the gitops/ Helm values.

locals {
  irsa_common = {
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_issuer       = module.eks.oidc_issuer
  }
}

module "irsa_alb_controller" {
  source = "../../../modules/irsa-role"

  name              = "${local.name}-alb-controller"
  oidc_provider_arn = local.irsa_common.oidc_provider_arn
  oidc_issuer       = local.irsa_common.oidc_issuer
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"
  # Official policy for chart v3.6.2:
  # https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.6.2/docs/install/iam_policy.json
  inline_policies = {
    controller = file("${path.module}/policies/alb-controller.json")
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.name}/*",
      module.data.db_master_secret_arn,
    ]
  }
}

module "irsa_external_secrets" {
  source = "../../../modules/irsa-role"

  name              = "${local.name}-external-secrets"
  oidc_provider_arn = local.irsa_common.oidc_provider_arn
  oidc_issuer       = local.irsa_common.oidc_issuer
  namespace         = "external-secrets"
  service_account   = "external-secrets"
  inline_policies = {
    read-app-secrets = data.aws_iam_policy_document.external_secrets.json
  }
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }
  # Can only resize/terminate ASGs that belong to this cluster.
  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${module.eks.cluster_name}"
      values   = ["owned"]
    }
  }
}

module "irsa_cluster_autoscaler" {
  source = "../../../modules/irsa-role"

  name              = "${local.name}-cluster-autoscaler"
  oidc_provider_arn = local.irsa_common.oidc_provider_arn
  oidc_issuer       = local.irsa_common.oidc_issuer
  namespace         = "kube-system"
  service_account   = "cluster-autoscaler"
  inline_policies = {
    autoscaler = data.aws_iam_policy_document.cluster_autoscaler.json
  }
}

data "aws_iam_policy_document" "loki" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.observability.loki_bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.observability.loki_bucket_arn}/*"]
  }
}

module "irsa_loki" {
  source = "../../../modules/irsa-role"

  name              = "${local.name}-loki"
  oidc_provider_arn = local.irsa_common.oidc_provider_arn
  oidc_issuer       = local.irsa_common.oidc_issuer
  namespace         = "monitoring"
  service_account   = "loki"
  inline_policies = {
    s3 = data.aws_iam_policy_document.loki.json
  }
}

# Grafana reads CloudWatch metrics and logs (RDS, ALB, WAF, EKS control plane).
module "irsa_grafana" {
  source = "../../../modules/irsa-role"

  name                = "${local.name}-grafana"
  oidc_provider_arn   = local.irsa_common.oidc_provider_arn
  oidc_issuer         = local.irsa_common.oidc_issuer
  namespace           = "monitoring"
  service_account     = "kube-prometheus-stack-grafana"
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]
}

data "aws_iam_policy_document" "alertmanager" {
  statement {
    actions   = ["sns:Publish"]
    resources = [module.observability.alerts_topic_arn]
  }
}

module "irsa_alertmanager" {
  source = "../../../modules/irsa-role"

  name              = "${local.name}-alertmanager"
  oidc_provider_arn = local.irsa_common.oidc_provider_arn
  oidc_issuer       = local.irsa_common.oidc_issuer
  namespace         = "monitoring"
  service_account   = "kube-prometheus-stack-alertmanager"
  inline_policies = {
    sns = data.aws_iam_policy_document.alertmanager.json
  }
}
