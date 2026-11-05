terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: this stack creates the S3 bucket that every other
  # stack keeps its state in (chicken-and-egg). It holds no secrets and is
  # tiny; after the first apply it can be migrated into the bucket with
  # `terraform init -migrate-state` (see README).
}

provider "aws" {
  region = var.region

  # Guard rail: refuse to touch any account except the take-home one.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "global"
      ManagedBy = "terraform"
    }
  }
}
