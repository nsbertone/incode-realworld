variable "name" {
  type = string
}

variable "repositories" {
  description = "ECR repositories to create (one per image)."
  type        = set(string)
  default     = ["backend", "frontend"]
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI roles."
  type        = string
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "build_branch" {
  description = "Only workflows on this branch may push images."
  type        = string
  default     = "main"
}

variable "tfstate_bucket" {
  type = string
}

variable "secrets_prefix" {
  description = "Secrets Manager name prefix the plan role may read (terraform refresh of secret versions)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
