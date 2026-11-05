variable "name" {
  description = "Cluster name."
  type        = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Subnets for nodes and the control plane ENIs."
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint (your IP, CI runners). Empty = private endpoint only."
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "IAM principals that get cluster-admin through EKS access entries."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large", "m5.large"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
