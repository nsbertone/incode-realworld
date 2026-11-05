variable "name" {
  description = "IAM role name."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_issuer" {
  description = "Issuer host/path without https:// (e.g. oidc.eks.eu-central-1.amazonaws.com/id/ABC)."
  type        = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "managed_policy_arns" {
  description = "AWS managed/customer policies to attach."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy name => JSON document."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
