variable "name" {
  type = string
}

variable "enable_guardduty_runtime_monitoring" {
  description = "GuardDuty EKS runtime agent. It creates its own VPC endpoint and security group, which blocks VPC deletion until removed, so it is off by default for this lab."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_inspector" {
  description = "Amazon Inspector: continuous CVE scanning of EC2 nodes and ECR images."
  type        = bool
  default     = true
}
