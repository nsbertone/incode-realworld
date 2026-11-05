locals {
  name = "${var.project}-${var.environment}"
}

# ---- Network tier ------------------------------------------------------------
module "network" {
  source = "../../../modules/network"

  name                       = local.name
  cidr                       = var.vpc_cidr
  cluster_name               = local.name
  single_nat_gateway         = var.single_nat_gateway
  enable_interface_endpoints = var.enable_interface_endpoints
  log_retention_days         = var.log_retention_days
}

# ---- Compute tier (EKS) -----------------------------------------------------
module "eks" {
  source = "../../../modules/eks"

  name                         = local.name
  kubernetes_version           = var.kubernetes_version
  vpc_id                       = module.network.vpc_id
  private_subnet_ids           = module.network.private_subnet_ids
  endpoint_public_access_cidrs = var.admin_cidrs
  admin_principal_arns         = var.admin_principal_arns
  node_instance_types          = var.node_instance_types
  node_capacity_type           = var.node_capacity_type
  node_desired_size            = var.node_desired_size
  log_retention_days           = var.log_retention_days
}

# ---- Data tier (RDS PostgreSQL) ---------------------------------------------
module "data" {
  source = "../../../modules/data"

  name                        = local.name
  vpc_id                      = module.network.vpc_id
  database_subnet_ids         = module.network.database_subnet_ids
  db_subnet_group_name        = module.network.database_subnet_group_name
  client_security_group_id    = module.eks.node_security_group_id
  db_instance_class           = var.db_instance_class
  db_multi_az                 = var.db_multi_az
  deletion_protection         = !var.lab_mode
  skip_final_snapshot         = var.lab_mode
  secret_recovery_window_days = var.lab_mode ? 0 : 7
  log_retention_days          = var.log_retention_days
}

# ---- Edge (CloudFront + WAF + ALB) ------------------------------------------
module "edge" {
  source = "../../../modules/edge"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name               = local.name
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  public_subnet_ids  = module.network.public_subnet_ids
  domain_name        = var.domain_name
  hosted_zone_id     = var.hosted_zone_id
  log_retention_days = var.log_retention_days
}

# Pods use the node security group (VPC CNI), so the ALB must be allowed into it
# on the two application ports. Nothing else from outside the cluster is.
resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  for_each = { frontend = 8080, backend = 8000 }

  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = module.edge.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "ALB to ${each.key} pods"
}

# ---- Backups ----------------------------------------------------------------
module "backup" {
  count  = var.enable_aws_backup ? 1 : 0
  source = "../../../modules/backup"
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name                = local.name
  retention_days      = var.lab_mode ? 7 : 35
  vault_lock_min_days = var.lab_mode ? null : 7
}

# Fallback when AWS Backup is not allowed: daily EBS snapshots (Prometheus,
# Grafana volumes) via Data Lifecycle Manager, same Backup=daily tag. The
# database is covered by RDS automated backups either way (module.data).
module "ebs_snapshots" {
  count  = var.enable_aws_backup ? 0 : 1
  source = "../../../modules/ebs-snapshots"

  name           = local.name
  retention_days = var.lab_mode ? 7 : 35
}

# ---- Security services ------------------------------------------------------
module "security" {
  source = "../../../modules/security"

  name             = local.name
  enable_inspector = var.enable_inspector
}

# ---- CI (ECR + GitHub OIDC roles) -------------------------------------------
module "ci" {
  source = "../../../modules/ci"

  name                     = local.name
  github_repo              = var.github_repo
  github_oidc_provider_arn = var.github_oidc_provider_arn
  tfstate_bucket           = var.tfstate_bucket
  secrets_prefix           = "${local.name}/"
}

# ---- Observability (Loki bucket, alerts topic) ------------------------------
module "observability" {
  source = "../../../modules/observability"

  name        = local.name
  alert_email = var.alert_email
}

# ---- Application secrets ----------------------------------------------------
resource "random_password" "django_secret_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/app"
  description             = "Django SECRET_KEY and other app-level secrets"
  recovery_window_in_days = var.lab_mode ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DJANGO_SECRET_KEY = random_password.django_secret_key.result
  })
}
