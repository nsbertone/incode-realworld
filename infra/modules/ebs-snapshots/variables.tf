variable "name" {
  type = string
}

variable "retention_days" {
  description = "Snapshots kept (one per day)."
  type        = number
  default     = 7
}

variable "time_utc" {
  type    = string
  default = "03:00"
}

variable "tag_key" {
  type    = string
  default = "Backup"
}

variable "tag_value" {
  type    = string
  default = "daily"
}

variable "tags" {
  type    = map(string)
  default = {}
}
