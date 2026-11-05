locals {
  admin_access_entries = {
    for i, arn in var.admin_principal_arns : "admin-${i}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  # API: private endpoint for nodes/pods, public endpoint only from allow-listed CIDRs.
  endpoint_private_access      = true
  endpoint_public_access       = length(var.endpoint_public_access_cidrs) > 0
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Access entries (API mode) instead of the aws-auth ConfigMap.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  access_entries                           = local.admin_access_entries

  # Envelope-encrypt Kubernetes Secrets with a KMS key the module creates.
  encryption_config = {
    resources = ["secrets"]
  }

  # Control-plane logs (incl. audit) -> CloudWatch.
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # IAM OIDC provider for IRSA.
  enable_irsa = true

  addons = {
    vpc-cni = {
      before_compute = true
      # Native NetworkPolicy enforcement in the VPC CNI (no Calico/Cilium needed).
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        env = {
          # Prefix delegation: many more pod IPs per node from the /20 private subnets.
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    kube-proxy = {
      before_compute = true
    }
    coredns = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.arn
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      subnet_ids = var.private_subnet_ids

      # IMDSv2 only, hop limit 1: pods cannot reach the node's instance role
      # credentials, so a compromised pod cannot borrow node permissions.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      update_config = {
        max_unavailable_percentage = 33
      }

      labels = {
        "node-role" = "general"
      }
    }
  }

  tags = var.tags
}

module "ebs_csi_irsa" {
  source = "../irsa-role"

  name                = "${var.name}-ebs-csi"
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_issuer         = module.eks.oidc_provider
  namespace           = "kube-system"
  service_account     = "ebs-csi-controller-sa"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  tags                = var.tags
}
