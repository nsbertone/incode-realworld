variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_ids" {
  type = list(string)
}

variable "db_subnet_group_name" {
  type = string
}

variable "client_security_group_id" {
  description = "The only security group allowed to reach the data tier (EKS nodes/pods)."
  type        = string
}

# ---- PostgreSQL
variable "postgres_version" {
  type    = string
  default = "18"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_name" {
  type    = string
  default = "conduit"
}

variable "db_username" {
  type    = string
  default = "conduit"
}

variable "db_multi_az" {
  description = "Synchronous standby in a second AZ with automatic failover."
  type        = bool
  default     = true
}

variable "db_backup_retention_days" {
  description = "Automated backups / point-in-time recovery window."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}

variable "secret_recovery_window_days" {
  description = "0 = delete secrets immediately on destroy (handy for a lab, not for prod)."
  type        = number
  default     = 7
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
