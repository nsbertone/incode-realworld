variable "account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "tfstate_bucket" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "repo_url" {
  description = "Git repo ArgoCD syncs from (this repository)."
  type        = string
}

variable "target_revision" {
  description = "Branch/tag ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  type    = string
  default = "10.11.6"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.7"
}
