variable "name" {
  description = "Name prefix (e.g. realworld-dev)."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR. Must not overlap other environments if they are ever peered."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "true = one NAT (cheap, egress depends on one AZ); false = one NAT per AZ (survives an AZ outage)."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Interface endpoints for ECR, STS and CloudWatch Logs (~7 USD/month each per AZ). The S3 gateway endpoint is always on (free)."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name, for subnet discovery tags."
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
