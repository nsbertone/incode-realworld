variable "name" {
  type = string
}

variable "schedule" {
  description = "Daily backup schedule (UTC)."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "retention_days" {
  type    = number
  default = 35
}

variable "dr_copy_retention_days" {
  description = "Retention of the cross-region copies."
  type        = number
  default     = 35
}

variable "vault_lock_min_days" {
  description = "Vault Lock (governance mode): recovery points cannot be deleted earlier than this, not even by an admin, unless the lock is removed by a privileged principal. null = no lock."
  type        = number
  default     = 7
}

variable "selection_tag_key" {
  type    = string
  default = "Backup"
}

variable "selection_tag_value" {
  type    = string
  default = "daily"
}

variable "tags" {
  type    = map(string)
  default = {}
}
