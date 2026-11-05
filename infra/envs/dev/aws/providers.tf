locals {
  default_tags = {
    Project     = var.project
    Environment = var.environment
    Stack       = "aws"
    ManagedBy   = "terraform"
    Repository  = var.github_repo
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "dr"
  region              = var.dr_region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = local.default_tags
  }
}
