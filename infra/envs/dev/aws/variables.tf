variable "account_id" {
  description = "The only AWS account this stack may run against."
  type        = string
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "dr_region" {
  description = "Region for cross-region backup copies."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  type    = string
  default = "realworld"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  description = "Per-environment, non-overlapping (dev 10.60/16, staging 10.61/16, prod 10.62/16)."
  type        = string
  default     = "10.60.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "enable_interface_endpoints" {
  type    = bool
  default = false
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint (e.g. your IP/32)."
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "Extra IAM principals with cluster-admin (the creator is admin already)."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large", "m5.large"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "lab_mode" {
  description = "true = easy teardown (no deletion protection, no final snapshot, secrets deleted immediately). Never in prod."
  type        = bool
  default     = true
}

variable "domain_name" {
  type    = string
  default = null
}

variable "hosted_zone_id" {
  type    = string
  default = null
}

variable "github_repo" {
  description = "owner/repo of this repository (CI OIDC trust)."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "From infra/global output."
  type        = string
}

variable "tfstate_bucket" {
  description = "From infra/global output."
  type        = string
}

variable "alert_email" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}
