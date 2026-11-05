data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Address plan inside the /16 (example 10.60.0.0/16):
  #   public   /24 x AZ  10.60.0.0  - 10.60.2.255   ALB, NAT
  #   private  /20 x AZ  10.60.16.0 - 10.60.63.255  EKS nodes AND pods (VPC CNI gives pods VPC IPs)
  #   database /24 x AZ  10.60.100.0- 10.60.102.255 RDS; no route to the internet
  public_subnets   = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, i)]
  private_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 4, i + 1)]
  database_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, i + 100)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  # Data tier is isolated: its own route table with no NAT and no IGW route.
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lock down the default security group (no rules) so nothing uses it by accident.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # VPC flow logs -> CloudWatch (who talked to whom; forensics).
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 600
  flow_log_cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = var.tags
}

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.7"

  vpc_id = module.vpc.vpc_id

  create_security_group      = var.enable_interface_endpoints
  security_group_name_prefix = "${var.name}-vpce-"
  security_group_description = "HTTPS from inside the VPC to interface endpoints"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [var.cidr]
    }
  }

  endpoints = merge(
    {
      # Free. Keeps S3 traffic (incl. ECR image layers, Loki chunks, backups) off the NAT.
      s3 = {
        service         = "s3"
        service_type    = "Gateway"
        route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids)
        tags            = { Name = "${var.name}-s3" }
      }
    },
    var.enable_interface_endpoints ? {
      for svc in ["ecr.api", "ecr.dkr", "sts", "logs"] : replace(svc, ".", "_") => {
        service             = svc
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        tags                = { Name = "${var.name}-${svc}" }
      }
    } : {}
  )

  tags = var.tags
}
