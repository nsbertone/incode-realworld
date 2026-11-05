variable "name" {
  type = string
}

variable "alert_email" {
  description = "Email subscribed to the alerts SNS topic (must confirm the subscription)."
  type        = string
}

variable "loki_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
