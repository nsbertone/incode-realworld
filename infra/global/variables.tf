variable "account_id" {
  description = "AWS account this stack is allowed to run against."
  type        = string
}

variable "region" {
  description = "Home region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used as a prefix for global resources."
  type        = string
  default     = "realworld"
}

variable "enable_budget" {
  description = "AWS Budgets alert. Off where an organization SCP denies budgets:* (the take-home account)."
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget; alerts at 80% actual and 100% forecasted."
  type        = number
  default     = 150
}

variable "budget_alert_email" {
  description = "Where budget alerts go."
  type        = string
}
