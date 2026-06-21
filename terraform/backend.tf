# ─────────────────────────────────────────
# backend.tf
# ─────────────────────────────────────────
# NOTE: S3 bucket was created manually via AWS CLI
# so it is NOT managed as a Terraform resource here.
# It is only used as the remote backend for state.
# ─────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "avinashsain65-terraform-state"
    key          = "ecommerce-store/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
