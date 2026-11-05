# ArgoCD bootstrap: the ONLY thing Terraform installs into the cluster.
#
#   1. helm_release.argocd  - ArgoCD itself
#   2. helm_release.root    - one "root" Application pointing at gitops/bootstrap
#
# From then on ArgoCD owns the cluster: the root app renders one Application
# per platform component + the app (app-of-apps). Values that only exist after
# `terraform apply` of the aws stack (role ARNs, target groups, bucket names)
# are handed over once, here, as Helm values of the root app.

data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = var.tfstate_bucket
    key    = "${var.environment}/aws.tfstate"
    region = var.region
  }
}

locals {
  aws = data.terraform_remote_state.aws.outputs

  # Contract between Terraform and gitops/bootstrap/values.yaml.
  cluster_values = {
    repoURL        = var.repo_url
    targetRevision = var.target_revision
    environment    = var.environment
    aws = {
      region    = local.aws.region
      accountId = local.aws.account_id
      vpcId     = local.aws.vpc_id
      vpcCidr   = local.aws.vpc_cidr
    }
    cluster = {
      name = local.aws.cluster_name
    }
    irsa = {
      albController     = local.aws.irsa_role_arns.alb_controller
      externalSecrets   = local.aws.irsa_role_arns.external_secrets
      clusterAutoscaler = local.aws.irsa_role_arns.cluster_autoscaler
      loki              = local.aws.irsa_role_arns.loki
      grafana           = local.aws.irsa_role_arns.grafana
      alertmanager      = local.aws.irsa_role_arns.alertmanager
    }
    targetGroups = {
      frontend = local.aws.target_group_arns.frontend
      backend  = local.aws.target_group_arns.backend
    }
    data = {
      dbHost            = local.aws.data.db_host
      dbPort            = local.aws.data.db_port
      dbName            = local.aws.data.db_name
      dbMasterSecretArn = local.aws.data.db_master_secret_arn
      appSecretName     = local.aws.data.app_secret_name
    }
    observability = {
      lokiBucket     = local.aws.loki_bucket
      alertsTopicArn = local.aws.alerts_topic_arn
    }
    images = {
      backend  = local.aws.ecr_repository_urls.backend
      frontend = local.aws.ecr_repository_urls.frontend
    }
    appUrl = local.aws.app_url
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [file("${path.module}/values/argocd.yaml")]

  wait    = true
  timeout = 600
}

resource "helm_release" "root" {
  name      = "argocd-root"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applications = {
      root = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "gitops/bootstrap"
          helm = {
            valuesObject = local.cluster_values
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
