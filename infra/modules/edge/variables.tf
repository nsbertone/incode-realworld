variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "domain_name" {
  description = "Optional public hostname (e.g. app.example.com). null = use the *.cloudfront.net name and HTTP between CloudFront and the ALB."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 zone for domain_name (required when domain_name is set)."
  type        = string
  default     = null
}

variable "frontend_port" {
  type    = number
  default = 8080
}

variable "backend_port" {
  type    = number
  default = 8000
}

variable "backend_health_path" {
  type    = string
  default = "/api/tags"
}

variable "login_rate_limit" {
  description = "Max requests per IP per 5 min to the login endpoint."
  type        = number
  default     = 100
}

variable "global_rate_limit" {
  description = "Max requests per IP per 5 min overall."
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
