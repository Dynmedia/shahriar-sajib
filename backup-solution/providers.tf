terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Management account provider - for org policies
provider "aws" {
  alias   = "mgmt"
  region  = var.region
  profile = var.management_account_profile
}

# Backup account provider - for vault and KMS resources
provider "aws" {
  alias   = "backup"
  region  = var.region
  profile = var.backup_account_profile
}
