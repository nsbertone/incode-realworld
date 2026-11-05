# Everything the argocd stack (and through it, gitops/) needs to know about AWS.

output "region" {
  value = var.region
}

output "account_id" {
  value = var.account_id
}

output "name" {
  value = local.name
}

output "app_url" {
  value = module.edge.url
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "irsa_role_arns" {
  value = {
    alb_controller     = module.irsa_alb_controller.arn
    external_secrets   = module.irsa_external_secrets.arn
    cluster_autoscaler = module.irsa_cluster_autoscaler.arn
    loki               = module.irsa_loki.arn
    grafana            = module.irsa_grafana.arn
    alertmanager       = module.irsa_alertmanager.arn
  }
}

output "target_group_arns" {
  value = {
    frontend = module.edge.frontend_target_group_arn
    backend  = module.edge.backend_target_group_arn
  }
}

output "data" {
  value = {
    db_host              = module.data.db_endpoint
    db_port              = module.data.db_port
    db_name              = module.data.db_name
    db_master_secret_arn = module.data.db_master_secret_arn
    app_secret_name      = aws_secretsmanager_secret.app.name
  }
}

output "loki_bucket" {
  value = module.observability.loki_bucket
}

output "alerts_topic_arn" {
  value = module.observability.alerts_topic_arn
}

output "ecr_repository_urls" {
  value = module.ci.ecr_repository_urls
}

output "ci_role_arns" {
  value = {
    build = module.ci.build_role_arn
    plan  = module.ci.plan_role_arn
  }
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --alias ${local.name}"
}
